# Build Walkthrough — node by node

A companion to [`sql/schema-explained.sql`](sql/schema-explained.sql): this explains
**every node** in all three workflows and the key expressions, so you can read —
and explain — exactly how the system works.

> n8n note: anything in `{{ ... }}` is an **expression** (a small JavaScript snippet
> n8n evaluates at run time). `$json` = the current item; `$('Node Name')` = data
> from another node; `$now` = the current date/time.

---

## Workflow 1 — Crawl  (`workflows/crawl.json`)

**Runs daily at 7am.** Goal: visit each competitor, detect what *actually* changed,
summarize only the changes, and store them. Flow:

```
Schedule → Get many rows → Loop Over Items → Switch → RSS Read → Limit
  → Edit Fields → Crypto → If ──true──→ Information Extractor → Build Document
                              │            → Vector Store → Create a row → Update a row ┐
                              └──false──────────────────────────────────→ (loop back) ─┘
```

**1. Schedule Trigger** — fires the workflow automatically.
- Cron `0 0 7 * * *`. n8n uses a 6-field cron (seconds first), so this = *second 0,
  minute 0, hour 7, every day* → **07:00 daily**.

**2. Get many rows** (Supabase) — loads the watch list.
- Table `competitors`, Return All on. Outputs one item per competitor, each carrying
  `competitor`, `url`, `type`, `brand`, `last_hash`, `last_text`.

**3. Loop Over Items** (Split in Batches) — processes **one competitor at a time**.
- Batch Size `1`. This isolation matters: it lets the "keep latest item" step work
  per-competitor instead of collapsing every feed into one.

**4. Switch** — routes each competitor by source type.
- Compares `={{ $json.type }}` against `rss` / `page` / `js`, with a named output each.
  Only the `rss` branch is wired (all current feeds are RSS-style); `page`/`js` are
  there for future non-feed sources.

**5. RSS Read** — fetches the competitor's feed.
- URL `={{ $json.url }}` (the current competitor's feed URL). Outputs the feed items.

**6. Limit** — keeps only the newest item.
- "Keep First Items = 1" → the latest post/article = the change signal.

**7. Edit Fields** (the "Normalize" step) — reshapes the data into one clean record.
Each field is set with an expression:
| Field | Expression | Meaning |
|---|---|---|
| competitor | `={{ $('Loop Over Items').item.json.competitor }}` | carry the name from the loop's current item |
| url | `={{ $('Loop Over Items').item.json.url }}` | carry the url |
| last_hash | `={{ $('Loop Over Items').item.json.last_hash \|\| '' }}` | previous hash; `\|\| ''` makes a null into an empty string so the IF compare is always string-vs-string |
| last_text | `={{ $('Loop Over Items').item.json.last_text \|\| '' }}` | previous text (for diffing) |
| text | `={{ ($json.title + ' — ' + ($json.content \|\| '')).toString().slice(0, 8000) }}` | the new content = title + body, capped at 8000 chars |
| brand | `={{ $('Loop Over Items').item.json.brand }}` | which business this competitor belongs to |

**8. Crypto** — fingerprints the content (this is the cost-saver).
- Action **Hash**, algorithm **SHA256**, Value `={{ $json.text }}`, output property `hash`.
  Same text → same hash; any change → different hash.

**9. If** — did the content change?
- Condition: `={{ $json.hash }}` **is not equal to** `={{ $json.last_hash }}`.
  - **false** (hash matches) → straight to *Update a row* — nothing changed, so the
    expensive AI step is skipped. **This is why a daily crawl costs pennies.**
  - **true** → continue to summarize.

**10. Information Extractor** (AI) — turns raw text into structured fields.
- Has an **OpenAI Chat Model** sub-node (`gpt-4o-mini`).
- Text input: `Previous content: {{ $json.last_text }}` + `New content: {{ $json.text }}`
  — gives the model both versions so it can describe what *changed*.
- Extracts four attributes: `change_type` (pricing/product/messaging/hiring/news/none),
  `significance` (high/medium/low), `summary`, `implication`. Output lands at `$json.output`.

**11. Build Document** (Set) — flattens everything into one record for storage.
- Fields use **`.first()`** instead of `.item` — e.g.
  `={{ $('Edit Fields').first().json.competitor }}`.
- **Why `.first()`?** The "paired-item" trail that `.item` relies on gets dropped when
  reaching back *through* the AI node above. Because the loop processes one competitor
  at a time, `.first()` reliably returns that single item. (This was a real bug we hit:
  `.item` returned `undefined` for some fields; `.first()` fixed it.)
- Builds `content` (summary + implication + competitor), plus `competitor`, `url`,
  `date` (`={{ $now.toISODate() }}`), `significance`, `change_type`, `brand`.

**12. Supabase Vector Store** (insert) — stores the change as an embedding (for chat).
- Table `competitor_intel`. Two sub-nodes:
  - **Embeddings OpenAI** → `text-embedding-3-small` (1536 dims — must match the table
    and the chat workflow, or retrieval returns garbage).
  - **Default Data Loader** → `Data` = the content to embed; `Metadata` = competitor,
    url, date, significance, change_type (so the chat can cite + filter).

**13. Create a row** (Supabase) — logs the change to `intel_log` (for the weekly digest).
- Maps competitor / url / change_type / significance / summary / implication / brand from
  `Build Document` and `Information Extractor`.

**14. Update a row** (Supabase) — saves the new fingerprint so tomorrow can diff.
- Matches the competitor by `url` = `={{ $('Crypto').item.json.url }}`, then sets
  `last_hash`, `last_text`, and `updated_at` (`={{ $now.toISO() }}`).
- **Wired back to Loop Over Items** so the loop continues to the next competitor (both
  the `true` and `false` paths loop back).

---

## Workflow 2 — Digest  (`workflows/digest.json`)

**Runs Mondays at 8am.** Turns the week's logged changes into one brief, split per brand.

**1. Schedule Trigger** — cron `0 0 8 * * 1` → *Monday 08:00*.

**2. Get many rows** (Supabase `intel_log`) — pulls the week's notable changes.
- Filters (Must Match All):
  - `created_at` **greater than** `={{ $now.minus(7,'days').toISO() }}` (last 7 days)
  - `significance` **not equals** `low` (skip trivial items)

**3. Aggregate** — bundles all rows into one item.
- "All Item Data → field `items`". Needed so the LLM runs **once** over the whole week,
  not once per row.

**4. Basic LLM Chain** (AI) — writes the brief.
- OpenAI Chat Model sub-node. Prompt instructs it to organize the brief into one section
  per brand, citing competitors by name, over `{{ JSON.stringify($json.items) }}`.
  (See [`prompts/weekly-digest.txt`](prompts/weekly-digest.txt).) Output at `$json.text`.

**5. Send a message ×2** — delivery.
- **Gmail** (subject `Weekly Competitor Intel Brief — {{ $now.toISODate() }}`, body
  `={{ $json.text }}`) **and** **Slack** (channel + `={{ $json.text }}`). Both read the
  same chain output, so the brief goes to inbox and Slack at once.

---

## Workflow 3 — Chat  (`workflows/chat.json`)

**Runs on demand.** A chat agent that answers questions over the stored intel (RAG).

**1. Chat Trigger** — the chat box (set public so it can be embedded).

**2. AI Agent** — decides when to search and writes the answer.
- System message (see [`prompts/chat-system.txt`](prompts/chat-system.txt)) tells it to
  answer **only** from the search tool and never invent facts. Three sub-nodes:

**3. OpenAI Chat Model** — `gpt-4o-mini` (the agent's brain).

**4. Simple Memory** — remembers the conversation (keyed to the chat session) for follow-ups.

**5. search_intel** (Supabase Vector Store, *retrieve-as-tool*) — the search tool.
- Mode "Retrieve Documents (As Tool for AI Agent)", table `competitor_intel`,
  **Query Name `match_competitor_intel`** (the SQL function), top-k `5`, Include Metadata on.
- Embeddings sub-node `text-embedding-3-small` — **must match** the crawl, or the question
  and the stored vectors live in different "spaces" and retrieval is meaningless.
- The agent embeds the question → the function returns the 5 closest change summaries →
  the agent answers, citing competitor + date.

---

## Gotchas & lessons (the non-obvious bits)

- **Change detection via hashing** — comparing a SHA-256 of today's content to yesterday's
  is what lets the crawl skip the LLM for unchanged feeds. Without it, you'd re-summarize
  everything daily and pay for it.
- **`.first()` vs `.item`** — inside a loop, reaching back *through* an AI/LangChain node
  with `.item` can silently return `undefined`. With batch size 1, `.first()` is the
  reliable way to grab the current item.
- **Embedding model must match everywhere** — the crawl (insert) and the chat (search)
  both use `text-embedding-3-small`. Mismatched models → garbage retrieval.
- **`match_competitor_intel` table-qualifies its columns** — see the comment in
  `schema-explained.sql`; without it Postgres errors `42702` ("column is ambiguous").
- **Multi-tenant by `brand`** — one pipeline serves several businesses because every
  record carries a `brand` tag, and the digest groups by it.

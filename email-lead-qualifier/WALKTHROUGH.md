# Walkthrough — Email Lead Qualifier

A node-by-node tour of the workflow: what each node does, the key expressions, and the
gotchas that cost real time. Read alongside
[`workflows/email-lead-qualifier.json`](workflows/email-lead-qualifier.json).

The shape:

```
Gmail Trigger → Get a message → Normalize → Information Extractor → Switch
                                                                     ├─ Hot  → Upsert → Slack → Label → AI reply → Reply(send) → Sheet
                                                                     ├─ Warm → Upsert → Slack → Label → AI reply → Reply(send) → Sheet
                                                                     └─ Dismiss → Mark as read
```

---

## 1. Gmail Trigger

- **Poll:** every minute · **Simplify:** on · **Max results:** 1
- **Filter:** `is:unread -label:qualified`

Only fresh, un-handled mail enters. The `-label:qualified` half is what makes the whole
thing idempotent: once a lead is labelled, it never re-enters.

> **Gotcha:** the Gmail Trigger only appears from an **empty canvas** (Tab / top-right
> `+`), never from another node's `+` (that list is actions only).

## 2. Get a message  *(the fix that matters)*

- **Operation:** Get · **Message ID:** `={{ $json.id }}` · **Simplify: OFF**

The trigger — and even *Get a message* with Simplify **on** — only give you a truncated
`snippet` plus a raw base64 `payload`. The actual email text isn't decoded. Since a
lead's budget and timeline usually sit a few lines into the body, a snippet-only body
makes the model score *every* lead `unclear`.

Turning **Simplify OFF** runs the message through n8n's mail parser and exposes decoded
**`text`** and **`html`** fields — the full body.

## 3. Normalize (Set)

Flattens everything the rest of the flow needs. Metadata comes from the **trigger** by
name (Get-a-message with Simplify off doesn't carry a clean `From`); the body comes from
**Get a message**:

| Field | Expression |
|-------|------------|
| `fromEmail` | `={{ $('Gmail Trigger').item.json.From.match(/<(.+?)>/) ? …[1] : …From }}` — bare address; this is the lead key |
| `fromRaw` | `={{ $('Gmail Trigger').item.json.From }}` |
| `subject` | `={{ $('Gmail Trigger').item.json.Subject }}` |
| `threadId` | `={{ $('Gmail Trigger').item.json.threadId }}` |
| `messageId` | `={{ $('Gmail Trigger').item.json.id }}` |
| `body` | `={{ ($('Get a message').item.json.text \|\| $('Get a message').item.json.html \|\| $('Gmail Trigger').item.json.snippet).slice(0, 4000) }}` |

> **Gotcha:** in Set expression-mode fields, type only `{{ … }}` — the leading `=` is
> the raw-JSON marker n8n adds itself. A literal `={{ … }}` glued into a value breaks
> the downstream Gmail message-ID calls.

## 4. Information Extractor (+ OpenAI Chat Model, gpt-4o-mini)

- **Text:** `Subject: {{ $json.subject }}\n\nFrom: {{ $json.fromRaw }}\n\n{{ $json.body }}`
- **Schema:** `is_lead` (bool), `name`, `company`, `budget`, `authority`, `need`,
  `timeline`, `score` (number), `stage`, `summary`
- **System prompt:** the BANT rubric — see [`prompts/classifier.txt`](prompts/classifier.txt)

Scores each lead 25 points per BANT dimension and sets `stage` to `qualified` /
`unclear` / `not_qualified`. Missing fields return the literal `"unknown"` (never
invented, never the word `undefined`).

> **Gotcha:** the result nests under **`output`** — downstream reads
> `{{ $json.output.stage }}`.

## 5. Switch (Rules, 3-way)

| Output | Condition (`{{ $json.output.stage }}`) |
|--------|----------------------------------------|
| **Hot** | equals `qualified` |
| **Warm** | equals `unclear` |
| **Dismiss** | fallback output (`not_qualified` + anything unexpected) |

> **Gotcha:** the compared value is the bare word (`qualified`), not a phrase; and the
> catch-all is the node's **Fallback Output**, not a rule literally matching
> "everything else".

## 6. Hot & Warm branches (identical shape, different tone)

**6a. Execute a SQL query — upsert**
Parameterized `INSERT … ON CONFLICT (email) DO UPDATE` into `email_leads`. Values are
passed as an **array** in Query Parameters (`$1…$11`), so apostrophes in `need` /
`summary` can't break the SQL. `stage` fills itself from the model (`qualified` vs
`unclear`). This node is *first* in the branch, so `$json.output.x` still points at the
extractor.

**6b. Slack — Send a message**
🔥 (hot) / 🌤️ (warm) alert. Because Slack sits *after* Postgres, it reaches back by
name: `$('Information Extractor').first().json.output.x`. Ends with a one-click deep
link: `https://mail.google.com/mail/u/0/#inbox/{{ $('Normalize').first().json.threadId }}`.

**6c. Add label — `qualified`**
`messageId = {{ $('Normalize').first().json.messageId }}`. The label doubles as the
"handled" marker that keeps the trigger from reprocessing.

**6d. Basic LLM Chain (+ gpt-4o-mini) — compose reply**
- **Source for Prompt: Define below** (there's no chat trigger to read `chatInput` from).
- Hot prompt pushes to book; warm prompt asks for budget + timeline. Both forbid
  placeholders and invented specifics — see
  [`prompts/hot-reply.txt`](prompts/hot-reply.txt) /
  [`prompts/warm-reply.txt`](prompts/warm-reply.txt).

**6e. Reply to a message — send**
`Message ID = {{ $('Normalize').first().json.messageId }}`, `Message = {{ $json.text }}`
(the chain output, taken directly since the reply node sits right after it). Auto-threads
the `Re:` reply to the original sender.

**6f. Append row in sheet**
Logs to the "Email Lead Tracker" board. `Status` is intentionally **unmapped** so your
manual `New → Contacted → Booked` edits are never overwritten (a mapped-but-empty column
blanks the cell).

## 7. Dismiss branch — Mark a message as read

`not_qualified` / spam / newsletters. Marking read drops them out of the `is:unread`
filter — no row, no Slack, no reply.

---

## The reusable lessons

1. **Full email body needs `Get a message` with Simplify OFF** — trigger snippets are
   truncated.
2. **Once a node changes `$json`, reach back by node name** (`.first()`), never bare
   `$json`.
3. **LLM Chains outside a chat flow use "Define below"**, not "Connected Chat Trigger
   Node".
4. **Auto-sent replies are guard-railed** — acknowledge and ask; never invent or use
   placeholder brackets.
5. **Don't dismiss incomplete leads** — the `unclear` → Warm branch captures and
   nurtures them.

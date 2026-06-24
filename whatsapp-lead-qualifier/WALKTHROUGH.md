# Build Walkthrough — node by node

How the WhatsApp Lead Qualifier works, explained so you can read and present it.
An agent chats with inbound WhatsApp leads, asks BANT questions over many turns, saves
structured data as it learns, and alerts sales when a lead qualifies.

> n8n note: `{{ ... }}` is an **expression** n8n evaluates at run time. `$fromAI('X')`
> means "the agent fills this value in when it calls the tool." See
> [`sql/schema-explained.sql`](sql/schema-explained.sql) and
> [`sql/upsert-lead-explained.sql`](sql/upsert-lead-explained.sql) for the database side.

```
WhatsApp Trigger → Edit Fields → Load Lead → AI Agent → Send message → Get many row → If(qualified) → Slack
                                              ├ OpenAI gpt-4o-mini
                                              ├ Postgres Chat Memory (keyed by phone)
                                              └ upsert_lead (Postgres tool)
```

**1. WhatsApp Trigger** — fires on every inbound WhatsApp `messages` event.

**2. Edit Fields** — pulls out the two things we need:
- `phone = {{ $json.messages[0].from }}` — the sender's number (also the lead's unique id)
- `text  = {{ $json.messages[0].text.body }}` — what they wrote

**3. Load Lead** (Supabase) — reads the existing lead row: `leads` where
`phone = {{ $('Edit Fields').item.json.phone }}`, limit 1. **`alwaysOutputData` is on**, so
it still returns an item for a brand-new lead (empty) — the agent always has *something* to
read as "known so far."

**4. AI Agent** — the qualifier. Input `text = {{ $('Edit Fields').item.json.text }}`. Its
system message is the **BANT** script (collect need / budget / authority / timeline,
one question at a time, keep a 0-100 score) and ends with
`Known so far: {{ JSON.stringify($('Load Lead').item.json) }}` — so it sees what's already
saved and doesn't re-ask. Three sub-nodes:
- **OpenAI Chat Model** — `gpt-4o-mini`.
- **Postgres Chat Memory** — `sessionKey = {{ $('Edit Fields').item.json.phone }}`, table
  `whatsapp_memory`. This is the running dialogue, keyed by phone, so a half-finished
  conversation can resume later.
- **upsert_lead** (Postgres tool) — the agent calls this to save facts. It runs an
  `INSERT … ON CONFLICT (phone) DO UPDATE` where each value comes from `$fromAI('name')`,
  `$fromAI('budget')`, etc. Two SQL tricks make partial saves work:
  - `NULLIF('{{ $fromAI("x") }}', '')` turns a blank the agent didn't supply into `NULL`.
  - `COALESCE(EXCLUDED.x, leads.x)` keeps the **existing** value when the new one is NULL.
  - Together: each message only overwrites the fields the agent actually learned, so the
    lead's profile **accumulates** across the conversation. (Full breakdown in
    `upsert-lead-explained.sql`.)

**5. Send message** (WhatsApp) — replies to the lead: to `{{ $('Edit Fields').item.json.phone }}`,
text `{{ $('AI Agent').item.json.output }}`.

**6. Get many row** (Supabase) — re-reads the lead *after* the agent's upserts, to get the
latest `stage`/fields.

**7. If** — `={{ $json.stage }}` **equals** `qualified`?

**8. Send a message** (Slack) — on `qualified`, alerts the sales channel:
*"New qualified lead — budget {{ $json.budget }}, timeline {{ $json.timeline }},
score {{ $json.score }}. Need: {{ $json.need }}"*.

## Gotchas & lessons

- **n8n runs statelessly per message**, so state lives in **two** places: the
  **Postgres Chat Memory** (the dialogue, keyed by phone) and the **`leads` table** (the
  structured fields + `stage`). A lead can drop off and resume days later.
- **`phone` is the primary key** — it's naturally unique, so it's both the lead id and what
  the upsert keys off (one row per lead, no duplicates).
- **Load before, read after.** *Load Lead* gives the agent context up front; *Get many row*
  re-reads the final state so the qualified-alert reflects the agent's latest upserts.
- **Partial-update upsert** (`NULLIF` + `COALESCE`) is the heart of it — without it, a
  message that only mentions "budget" would wipe the name/company the agent learned earlier.

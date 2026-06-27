# Build Walkthrough — node by node

How the RAG support chatbot works, explained so you can read and present it. It's
**two workflows sharing one Supabase table** (`documents`): one *ingests* docs
from Google Drive, the other *answers* questions from them.

> n8n note: `{{ ... }}` is an **expression** n8n evaluates at run time.
> `$('Node Name').item.json.x` reads a field from an earlier node. See
> [`sql/schema-explained.sql`](sql/schema-explained.sql) for the database side.

---

## Workflow A — Ingestion (scheduled, *writes* to `documents`)

```
Schedule → Postgres (DELETE FROM documents) → Drive Search → Drive Download → Extract from File → Supabase Vector Store (Add documents)
                                                                                                      ├ Default Data Loader
                                                                                                      ├ Recursive Text Splitter (800/100)
                                                                                                      └ Embeddings OpenAI
```

**1. Schedule Trigger** — runs the sync on an interval (e.g. hourly). For testing
you run it manually with *Execute workflow*.

**2. Execute a SQL query** (Postgres) — `DELETE FROM documents;`. This is the dedup
strategy: because step 3 re-scans the *whole* folder every run, we wipe the table
first and reload it, so chunks never duplicate and files you removed from Drive
drop out. **`alwaysOutputData` is on** so an empty delete still passes an item
downstream (otherwise the chain would stop on the first run).

**3. Search files and folders** (Google Drive) — lists the watched folder.
**Filter → Folder** = your support-docs folder, **Return All** on, search query
empty (we want everything). Outputs one item per file, each with `id` and `name`.

**4. Download file** (Google Drive) — `File ID = {{ $json.id }}`. Fetches each
file's bytes as binary so we can read its text.

**5. Extract from File** — operation **Extract from Text** (use *Extract from PDF*
for PDFs). Turns the binary into text. ⚠️ The text lands in a field called
**`data`** (the "Destination Output Field"), not `text` — that matters for the next node.

**6. Supabase Vector Store — "Add documents to vector store"** (table `documents`).
This is where chunking + embedding + insert happen, via three sub-nodes:
- **Default Data Loader** — Mode **Load Specific Data**, Data to Load
  `={{ $json.data }}` (the extracted text — *expression mode*, not fixed, or it
  stores the literal `{{ }}`). **Metadata** carries the file identity, referenced
  straight from the Search node so it survives Download/Extract:
  `fileId = {{ $('Search files and folders').item.json.id }}`,
  `fileName = {{ $('Search files and folders').item.json.name }}`.
- **Recursive Character Text Splitter** — Chunk Size **800**, Overlap **100**.
- **Embeddings OpenAI** — `text-embedding-3-small` (1536-d).

➡️ Result: each file becomes ~2 rows in `documents`, each with real `content`,
`fileName` in metadata, and a 1536-d `embedding`.

---

## Workflow B — Chatbot (on demand, *reads* from `documents`)

```
Chat Trigger → AI Agent (Tools Agent)
                  ├ OpenAI Chat Model (gpt-4o-mini)
                  ├ Simple Memory (per session)
                  └ Supabase Vector Store as Tool  →  Embeddings OpenAI
```

**1. Chat Trigger** — provides the chat panel; outputs `chatInput` and `sessionId`.

**2. AI Agent** (Tools Agent) — the brain. Source for Prompt = the connected Chat
Trigger; system message = the **grounding prompt** (answer only from retrieved
docs, cite the filename, refuse + escalate otherwise — see
[`prompts/grounding-prompt.txt`](prompts/grounding-prompt.txt)). Sub-nodes:
- **OpenAI Chat Model** — `gpt-4o-mini`.
- **Simple Memory** — Session Key from the trigger's `sessionId`, so follow-ups
  ("how long does *that* take?") resolve against earlier turns.
- **Supabase Vector Store — "Retrieve Documents As Tool for AI Agent"** — exposed
  to the agent as a tool named **`search_docs`** (table `documents`, limit **5**).
  Its own **Embeddings OpenAI** sub-node must be **`text-embedding-3-small`** — the
  *same* model as ingestion. The agent calls this tool when it needs facts; the
  tool embeds the question, runs `match_documents`, and returns the top-5 chunks
  (with their `fileName` metadata, which is how the bot cites sources).

➡️ Result: a grounded, cited answer — or a polite refusal + escalation offer when
the docs don't cover the question.

---

## Gotchas & lessons

- **Same embedding model both sides.** `text-embedding-3-small` for ingestion *and*
  retrieval. Mismatched models = vectors in different spaces = silently-wrong
  results. The table's `vector(1536)` is tied to this model.
- **"Data to Load" must be an Expression, not Fixed.** In Fixed mode the Data
  Loader stores the literal string `{{ $json.data }}` as the content. Toggle the
  field to Expression (or it never resolves).
- **"Load Specific Data", not "Load All Input Data".** "Load All" embeds *every*
  field as its own document — you get junk rows containing bare filenames/ids.
  Point the loader at the text field only.
- **Extract from File outputs `data`, not `text`.** Reference `$json.data`.
- **Carry file identity from the Search node.** `id`/`name` get dropped after
  Download/Extract, so the Data Loader's metadata reads them from
  `$('Search files and folders')` directly.
- **Dedup = wipe + reload.** With multiple files flowing through, a per-file
  `metadata->>'fileId'` delete hits paired-item ambiguity ("can't figure out the
  matching item"). The simplest robust fix for a small folder is `DELETE FROM
  documents;` at the start of the run, then re-ingest everything.
- **Triggers are added from empty canvas.** The Google Drive *Trigger* doesn't
  appear when you add a node from another node's `+` (that menu shows actions
  only). Here we use **Schedule + Drive "Search files and folders"** as the watcher
  instead — same effect, and it sidesteps that entirely.
- **Vector store as a *tool*, not a fixed QA chain.** Letting the agent decide when
  to call `search_docs` enables multi-hop lookups and natural refusals.

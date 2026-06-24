# Build Walkthrough — node by node

How the Multi-Tool Telegram Agent works, explained so you can read and present it.
It handles **text and voice**, routes them, runs a tool-using agent, and replies with
**both a text answer and a generated audio note**.

> n8n note: `{{ ... }}` is an **expression** n8n evaluates at run time. `$json` = the
> current item; `$('Node Name')` = data from another node.

```
Telegram Trigger → Switch ─Text──→ Edit Fields ─────────────────┐
                          └Audio─→ Get a file → Transcribe ──────┤
                                                                 ↓
                                                              AI Agent
                                            (OpenAI gpt-4o · memory · 3 tools)
                                                                 │
                                  ┌──────────────────────────────┴───────────┐
                          Send a text message               Basic LLM Chain → Generate audio → Send an audio file
```

**1. Telegram Trigger** — fires on every incoming Telegram `message` (text or voice).

**2. Switch** — splits text vs voice by checking which field exists:
- **Text** output: `={{ $json.message.text }}` *exists*
- **Audio** output: `={{ $json.message.voice.file_id }}` *exists*

**3a. Edit Fields** (text branch) — pulls the message into a clean field:
`Text = {{ $json.message.text }}`.

**3b. Get a file → Transcribe a recording** (voice branch):
- **Get a file** (Telegram) downloads the voice note by `{{ $json.message.voice.file_id }}`.
- **Transcribe a recording** (OpenAI **Whisper**) converts the audio to text.
Both branches end up feeding the AI Agent, so text and voice are handled the same way downstream.

**4. AI Agent** — the brain. Input `text = {{ $json.Text }}`; its system message defines a
friendly, concise persona and the tools it may use (email, calendar, web search). It has:
- **OpenAI Chat Model** — `gpt-4o`.
- **Simple Memory** — keyed by `={{ $('Switch').item.json.message.chat.id }}` (per-chat
  history), last 10 turns.
- **Three tools** (each a *sub-workflow* — `toolWorkflow` nodes): **Search Agent**,
  **Sub Calendar Agent**, **Call 'Sub Workflow Mails'**. The agent picks one by reading
  its description (same description-driven routing as the MCP build).

**5. The dual reply** — the agent's output fans out to two paths:
- **Send a text message** (Telegram) → `chatId = {{ $('Switch').item.json.message.chat.id }}`,
  `text = {{ $json.output }}` — the normal text answer.
- **Basic LLM Chain** (a playful "answer in one line" persona) → **Generate audio**
  (OpenAI text-to-speech) → **Send an audio file** (Telegram `sendAudio`) — a short spoken reply.

So a user can talk *or* type, and gets back both a written answer and a voice note.

## Gotchas & lessons

- **One agent, two input modes.** The Switch + Whisper transcription means voice and text
  converge into the same `Text` field before the agent — you only build the brain once.
- **Memory is keyed by chat id**, so each Telegram conversation keeps its own context.
- **The three tools are *sub-workflows*** (search / calendar / mail), referenced by ID.
  They live in the n8n instance and aren't exported here — that's the one piece to add if
  you want this fully reproducible from the repo alone.

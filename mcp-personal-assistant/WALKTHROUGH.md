# Build Walkthrough — node by node

How the MCP Personal Assistant works, explained so you can read and present it.
It's **two workflows** that meet over MCP: the **assistant** (the brain) and the
**MCP server** (the toolbox).

> n8n note: `{{ ... }}` is an **expression** (a small snippet n8n evaluates at run
> time). `$fromAI('X')` means "the agent fills this argument in when it calls the tool."

---

## Workflow A — The assistant  (`workflows/mcp-personal-assistant.json`)

```
When chat message received → AI Agent
                               ├─ OpenAI Chat Model  (the brain)
                               ├─ Simple Memory      (remembers the chat)
                               └─ MCP Client         (reaches the toolbox)
```

**1. When chat message received** (Chat Trigger) — the chat box the user types into.
Embeddable on a site; outputs the user's message + a `sessionId`.

**2. AI Agent** — the decision-maker. It reads the user's message and decides which
tool(s) to call. Its **system message** lists the tool areas and the operating rules —
most importantly *"confirm before any irreversible action (sending email, creating an
event) by restating what you'll do and waiting for a yes."* It has three sub-nodes:

**3. OpenAI Chat Model** — `gpt-4o-mini`, the LLM doing the reasoning.

**4. Simple Memory** — a window buffer keeping the last **10** turns, so the assistant
remembers context within a conversation.

**5. MCP Client** — the bridge. Its `endpointUrl` points at the MCP server's URL
(`…/mcp/YOUR-MCP-SERVER-PATH`). On connect it pulls in **every tool the server exposes**
and hands them to the agent. Swap the server and the assistant gains new tools without
any rewiring here.

---

## Workflow B — The MCP server / toolbox  (`workflows/mcp-server-tools.json`)

This workflow turns a plain n8n flow into an **MCP server** that *any* MCP client can
call (this assistant, Claude Desktop, Cursor…). The trigger has eight tools hanging off it.

**1. MCP Server Trigger** — the server's front door. Its `path` is the URL clients connect
to. Every node connected to it as a *tool* becomes callable over MCP.

**The 8 tools** (each wired to the trigger as an `ai_tool`):

| Tool | What it does | How the agent fills it |
|---|---|---|
| Create an event in Google Calendar | adds a calendar event | `$fromAI('Start')`, `$fromAI('End')` |
| Send a message in Gmail | sends an email | `$fromAI('Subject')`, `$fromAI('Message')` |
| Get many events in Google Calendar | reads upcoming events | `$fromAI('After')`, `$fromAI('Before')` |
| Calculator | exact arithmetic | (model passes the expression) |
| Get row(s) in sheet in Google Sheets | reads a spreadsheet | sheet `YOUR_GOOGLE_SHEET_ID` |
| Google search in SerpApi | live web search | `$fromAI('Search_Query__q_')` |
| Create a row in Supabase | saves a note to `notes` | `$fromAI(...)` for content + tags |
| Get many rows in Supabase | recalls saved notes | sorted `created_at.desc` |

**Two ideas that make this work:**

- **`$fromAI()`** — the tool's arguments aren't hard-coded; the agent supplies them at
  call time (the email subject/body, the calendar times, the note text). The tool defines
  the *shape*; the model fills the *values*.
- **Description-driven routing (the core skill)** — there is **no Switch node** choosing
  tools. The agent picks by reading each tool's **name + description**. Where two tools look
  similar, the descriptions disambiguate — e.g. the notes-recall tool says *"…This is NOT
  spreadsheet data,"* so the agent never confuses it with the Sheets reader.

---

## Why split it into two workflows?

Decoupling the **tools** (server) from the **brain** (agent) means the same toolbox is
reusable by other clients, and the assistant's front door can be swapped (Chat →
Telegram / WhatsApp / web widget) without touching the tools.

## Gotchas & lessons

- **Gate irreversible actions.** Reading/searching/saving needs no confirmation; sending
  email or creating events does — enforced in the system prompt, not in code.
- **Authenticate the server before exposing it.** The MCP Server Trigger can run no-auth
  for local dev, but since its tools send email and write calendar events, set
  **Bearer Auth** on the trigger (and match it in the client) before sharing the URL.
- **One server, many clients.** The same `/mcp/...` endpoint serves this assistant *and*
  Claude Desktop — that's the point of MCP.

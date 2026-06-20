🤖 MCP-Powered Personal Assistant Agent
A modular personal assistant built with the Model Context Protocol (MCP) — connecting multiple tools (calendar, email, web search, memory, files) under a single intelligent agent with a clean chat interface.
---
🧠 What It Does
Accepts natural language requests via a chat UI (web or Telegram)
Routes requests to the correct MCP tool automatically using LLM function calling
Manages calendar events, reads/sends email, searches the web, and recalls past context
Maintains persistent memory across sessions
Returns structured, conversational responses
---
🏗 Architecture
```
User (Chat UI)
      │
      ▼
  LLM Agent (GPT-4o / Claude)
      │
      ├── MCP Tool: Calendar (Google Calendar API)
      ├── MCP Tool: Email (Gmail API)
      ├── MCP Tool: Web Search (SerpAPI / Tavily)
      ├── MCP Tool: Memory (vector store / simple KV)
      ├── MCP Tool: File Reader (Google Drive / local FS)
      └── MCP Tool: Task Manager (Notion / Todoist)
```
---
🛠 MCP Tool Setup
Tool	MCP Server	Credentials Needed
Google Calendar	`@modelcontextprotocol/server-google-calendar`	OAuth2
Gmail	`@modelcontextprotocol/server-gmail`	OAuth2
Web Search	`@modelcontextprotocol/server-brave-search`	Brave API key
File System	`@modelcontextprotocol/server-filesystem`	Local path config
Memory	`@modelcontextprotocol/server-memory`	None
Notion	`@modelcontextprotocol/server-notion`	Notion API key
MCP Config (`mcp_config.json`)
```json
{
  "mcpServers": {
    "calendar": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-google-calendar"] },
    "gmail":    { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-gmail"] },
    "search":   { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-brave-search"],
                  "env": { "BRAVE_API_KEY": "your_key" } },
    "memory":   { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-memory"] },
    "files":    { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem",
                  "/path/to/allowed/directory"] }
  }
}
```
---
🔀 Tool Routing Logic
The agent uses a system prompt to govern routing decisions:
```
You are a personal assistant with access to the following tools:
- calendar: for anything about scheduling, events, reminders, availability
- gmail: for reading, drafting, or sending emails
- search: for current information, news, prices, or facts you don't know
- memory: for storing and recalling user preferences, past context, or notes
- files: for reading documents the user has stored

Always pick the minimum number of tools needed. If a task requires multiple tools, 
chain them sequentially and summarize the result as a single cohesive response.
Never call a tool unless you are confident it is needed.
```
---
💬 Chat Interface Options
Option A — Claude Desktop (fastest to ship)
Add the `mcp_config.json` to Claude Desktop settings. Zero frontend code needed.
Option B — Custom Web Chat (React + FastAPI)
```
frontend/     React chat UI (Tailwind + shadcn)
backend/      FastAPI server
  └── agent.py   LLM agent loop with MCP client
  └── mcp.py     MCP session manager
```
Option C — Telegram Bot
Use `python-telegram-bot` as the interface layer. Agent runs server-side, responds to messages.
---
⚙️ Tech Stack
LLM: OpenAI GPT-4o or Claude 3.5 Sonnet
MCP Runtime: Node.js (MCP servers) + Python (agent orchestration via `mcp` SDK)
Chat UI: Claude Desktop / React / Telegram
Memory: MCP memory server (in-session) + Pinecone (long-term)
Auth: Google OAuth2, API keys via env vars
---
📸 Architecture Diagram / Screenshot
![Architecture](./screenshot.png)
---

🚀 How to Use
Clone this repo
Run `npm install` to pull MCP server packages
Copy `.env.example` to `.env` and fill in your API keys
Run `python agent.py` (or open in Claude Desktop)
Start chatting — "What's on my calendar tomorrow?" / "Search for the latest AI news"
---
💡 Key Design Decisions
MCP over custom tool wrappers: each tool is hot-swappable without touching the agent core
Routing via system prompt (not hard-coded if/else): LLM decides based on intent
Memory tool called first on every session start to restore user context
---
👤 Author
Patrick Sales — Senior Automation & AI Engineer  
LinkedIn | GitHub

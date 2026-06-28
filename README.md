# 🤖 n8n Automation Portfolio

A collection of production-ready AI automation workflows built with n8n, OpenAI, and complementary tools. Each project solves a real business problem — lead generation, customer support, competitive intelligence, and more.

Every folder is a self-contained case study: a README with the problem it solves and
the result, an architecture diagram, the exported workflow JSON, and a node-by-node
walkthrough. Click any project below.

---

## 📂 Projects

| Project | The problem it solves | Stack |
|---------|-----------------------|-------|
| [mcp-personal-assistant](./mcp-personal-assistant/) | **Scattered daily tasks → one chat.** A single agent reaches calendar, email, sheets, notes, web search, and math over MCP — picking the right tool itself, gating irreversible actions. | MCP · GPT-4o-mini · Supabase · n8n |
| [competitor-intelligence](./competitor-intelligence/) | **Replaces a $100s/mo SaaS.** Tracks competitors daily, uses AI to surface *only what changed* (hash-diff keeps it cents/day), and ships a sectioned weekly brief + a RAG chat — across 3 businesses. | n8n · OpenAI · Supabase/pgvector · Slack |
| [whatsapp-lead-qualifier](./whatsapp-lead-qualifier/) | **No inbound lead goes cold.** Answers WhatsApp leads instantly 24/7, runs a full BANT qualification, saves state per phone (resumable), then routes hot leads to a booking link + Slack alert. | n8n · OpenAI · Supabase · WhatsApp · Slack |
| [rag-support-chatbot](./rag-support-chatbot/) | **Support answers that don't hallucinate.** Auto-syncs a Google Drive folder into a vector store and answers *only* from those docs — cites the source file, refuses what isn't documented. | n8n · OpenAI · Supabase/pgvector · Google Drive |
| [social-content-bot](./social-content-bot/) | **Autoposting with a human gate.** Turns one idea into platform-tailored posts, self-critiques for quality, then *pauses* for Slack Approve/Decline before publishing — and logs the live link back. | n8n · OpenAI · Google Sheets · Slack · Ayrshare |
| [telegram-agent](./telegram-agent/) | **Hands-free assistant in Telegram.** Takes voice or text, transcribes with Whisper, and routes to tools for calendar, email, and web search — replying by text or audio. | n8n · GPT-4o · Telegram · Whisper |

> 🎥 Short demo videos for each workflow are on the way — to be added in one pass once all builds are complete.

---

## 🛠 Core Stack

- **Orchestration:** n8n (cloud / self-hosted)
- **LLM:** OpenAI GPT-4o / GPT-4o-mini (+ Whisper for voice)
- **Vector DB:** Supabase (Postgres + pgvector)
- **Memory:** n8n Simple Memory · Postgres Chat Memory
- **Interfaces:** Telegram · WhatsApp · Web chat · Gmail · Slack
- **Integrations:** MCP · SerpAPI (web search) · Google Calendar / Sheets

---

## 🚀 How to Use Any Project

1. Navigate into the project folder
2. Import `workflow.json` into your n8n instance
3. Follow the setup steps in that project's `README.md`
4. Add your credentials and activate

---

## 👤 About

**Patrick Sales** — Senior Automation & AI Engineer  
Building AI agents and workflow automations that eliminate manual work.

[LinkedIn](https://www.linkedin.com/in/patrickomarsales/) | [Email](mailto:fatquicksales0022@gmail.com)

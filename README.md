# 🤖 n8n Automation Portfolio

A collection of production-ready AI automation workflows built with n8n, OpenAI, and complementary tools. Each project solves a real business problem — lead generation, customer support, competitive intelligence, and more.

---

## 📂 Projects

| Project | Description | Stack |
|---------|-------------|-------|
| [mcp-personal-assistant](./mcp-personal-assistant/) | MCP-powered personal assistant with calendar, email, search, memory, and notes | MCP · GPT-4o-mini · Supabase · n8n |
| [competitor-intelligence](./competitor-intelligence/) | Tracks competitors daily, summarizes only what changed with AI, delivers a weekly digest + a RAG chat | n8n · OpenAI · Supabase/pgvector · Slack |
| [whatsapp-lead-qualifier](./whatsapp-lead-qualifier/) | Qualifies inbound leads over WhatsApp — multi-turn BANT conversation, persistent state, scoring, and a Slack alert on hot leads | n8n · OpenAI · Supabase · WhatsApp · Slack |
| [rag-support-chatbot](./rag-support-chatbot/) | Customer-support chatbot that auto-syncs a Google Drive folder into a vector store and answers grounded in those docs — cites sources, refuses what isn't documented | n8n · OpenAI · Supabase/pgvector · Google Drive |
| [telegram-agent](./telegram-agent/) | Multi-tool AI agent triggered by Telegram — handles text & voice, tools for calendar, email, and web search | n8n · GPT-4o · Telegram · Whisper |

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

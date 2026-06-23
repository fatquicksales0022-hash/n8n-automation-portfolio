# 🤖 n8n Automation Portfolio

A collection of production-ready AI automation workflows built with n8n, OpenAI, and complementary tools. Each project solves a real business problem — lead generation, customer support, competitive intelligence, and more.

---

## 📂 Projects

| Project | Description | Stack |
|---------|-------------|-------|
| [telegram-agent](./telegram-agent/) | Multi-tool AI agent triggered by Telegram — handles text & voice, tools for calendar, email, and web search | n8n · GPT-4o · Telegram · Whisper |
| [lead-assistant](./lead-assistant/) | AI agent that captures, qualifies, and writes leads to CRM automatically | n8n · GPT-4o · HubSpot · Gmail |
| [rag-chatbot](./rag-chatbot/) | RAG chatbot that answers questions from your own documents, auto-synced from Google Drive | n8n · Pinecone · OpenAI · Google Drive |
| [email-automation](./email-automation/) | Reads, classifies, drafts, and sends emails autonomously | n8n · GPT-4o · Gmail |
| [competitor-intelligence](./competitor-intelligence/) | Tracks competitors daily, summarizes only what changed with AI, delivers a weekly digest + a RAG chat | n8n · OpenAI · Supabase/pgvector · Slack |
| [whatsapp-lead-qualifier](./whatsapp-lead-qualifier/) | Qualifies leads via WhatsApp conversation with persistent state + CRM writes | n8n · GPT-4o · WhatsApp API · HubSpot |
| [rag-support-chatbot](./rag-support-chatbot/) | Customer support chatbot with semantic search over your knowledge base | n8n · Pinecone · GPT-4o · Google Drive |
| [social-media-bot](./social-media-bot/) | Generates and publishes platform-native content to LinkedIn, Twitter, Instagram | n8n · GPT-4o · LinkedIn API · Buffer |
| [email-triage-agent](./email-triage-agent/) | Classifies every inbound email, drafts replies, archives noise, alerts on urgent | n8n · GPT-4o · Gmail · Google Calendar |
| [mcp-personal-assistant](./mcp-personal-assistant/) | MCP-powered personal assistant with calendar, email, search, memory, and files | MCP · GPT-4o / Claude · Node.js |

---

## 🛠 Core Stack

- **Orchestration:** n8n (self-hosted)
- **LLM:** OpenAI GPT-4o
- **Vector DB:** Pinecone
- **Memory:** n8n Simple Memory 
- **Interfaces:** Telegram · WhatsApp · Web · Gmail
- **LLM Chaining:** Flowise
- **Scraping:** Apify · SerpAPI

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

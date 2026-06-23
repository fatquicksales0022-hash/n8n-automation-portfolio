# 🤖 Multi-Tool Telegram AI Agent

A production-ready AI agent built in n8n that handles both text and voice 
messages via Telegram, routes them intelligently, and responds using 
multi-tool function calling with persistent memory.

---

## 🧠 What It Does

- Accepts **text and voice messages** from Telegram
- Transcribes voice notes via OpenAI Whisper
- Routes messages through a **Switch node** (text vs. audio path)
- Passes input to an **AI Agent** with memory and tool access
- Responds via **text or generated audio** back to Telegram

---

## 🛠 Tools Available to the Agent

| Tool | Purpose |
|------|---------|
| Sub Calendar Agent | Read/write Google Calendar events |
| Call 'Sub Workflow Mails' | Send and read emails |
| Search Agent | Web search via SerpAPI or similar |

---
## 📸 Workflow Screenshot

![Workflow](docs/workflow.png)

## ⚙️ Tech Stack

- **Platform:** n8n (self-hosted / cloud)
- **LLM:** OpenAI GPT-4o
- **Memory:** n8n Simple Memory
- **Voice:** OpenAI Whisper (transcription) + TTS (audio reply)
- **Trigger:** Telegram Bot API

---

## 🚀 How to Use

1. Import `workflows/multi-tool-telegram-agent.json` into your n8n instance
2. Set credentials: Telegram Bot, OpenAI, Gmail/Calendar
3. Activate the workflow
4. Message your Telegram bot

---

## 👤 Author

**Patrick Sales** — Senior Automation & AI Engineer  
[LinkedIn](#) | [GitHub](#)

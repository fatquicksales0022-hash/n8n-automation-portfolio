# 🤖 n8n Automation Portfolio

A collection of production-ready AI automation workflows built with n8n, OpenAI, and complementary tools. Each project solves a real business problem — lead generation, customer support, competitive intelligence, and more.

Every folder is a self-contained case study: a README with the problem it solves and
the result, an architecture diagram, the exported workflow JSON, and a node-by-node
walkthrough. Click any project below.

---

## 📂 Projects

| Project | The problem it solves | Stack |
|---------|-----------------------|-------|
| [speedlead](./speedlead/) | **Every lead answered in under a minute.** Catches a web-form enquiry the instant it lands, **AI-scores** how hot it is (1–10), and routes it — **hot** leads get an instant personalized reply + Slack alert, cold leads get tagged for nurture. Validates + **de-duplicates** at the door, captures *before* the AI so an outage never loses a lead, then logs every hot lead to Sheets and pings the owner. Two platforms by design: **Make** runs the real-time response, **Zapier** runs the CRM logging. | Make · Zapier · Airtable · GPT-4o-mini · Slack · n8n |
| [cash-chaser](./cash-chaser/) | **Invoices that chase themselves.** Polls **Xero** daily, finds what's genuinely overdue, and AI-writes each customer a reminder in a tone that escalates with the debt — friendly at 7 days, firm at 14, final at 30+. A Sheets ledger means it never re-sends the same level, **auto-stops and thanks the customer** the moment they pay, and holds **final notices for one-click owner approval**. Mondays it emails the owner a branded cash-flow brief. | n8n · Xero · GPT-4o-mini · Google Sheets · Gmail |
| [outbound-feedback-bot](./outbound-feedback-bot/) | **An AI rep that calls your customers.** Dials existing customers by phone, checks in on their last order, **reads sentiment**, **qualifies new opportunities**, then logs *every* call to a sheet and emails *only* the qualified leads — with **opt-out / do-not-call** honored automatically (skipped before dial, auto-added on request). | Vapi · n8n · Twilio · GPT-4o-mini · Google Sheets · Gmail |
| [ai-voice-front-desk](./ai-voice-front-desk/) | **A receptionist that answers the phone.** Handles inbound calls by voice — qualifies, **books mid-call** with round-robin across staff + an availability guard (no double-booking), confirms + SMSes, and **transfers to a human** on request. Also runs **outbound**, dialing a lead list with a personalized pitch — plus a **Vapi realtime upgrade** that runs the same booking brain behind streaming speech-to-speech (~840ms latency) for a natural, low-lag inbound call. | Twilio · **Vapi** · n8n · GPT-4o-mini · Google Calendar · Sheets |
| [hvac-smart-dispatch](./hvac-smart-dispatch/) | **Triage → dispatch → invoice, hands-free.** Reads a field-service request from any channel, AI-classifies **urgency + the skill required**, matches an available technician (roster filter + calendar), books the job, and **auto-generates the invoice** on completion — one channel-agnostic brain across Chat, Gmail, and Telegram (`NEW → BOOKED → DONE → INVOICED`). | n8n · GPT-4o-mini · Google Sheets · Google Calendar · Gmail/Telegram |
| [mcp-personal-assistant](./mcp-personal-assistant/) | **Scattered daily tasks → one chat.** A single agent reaches calendar, email, sheets, notes, web search, and math over MCP — picking the right tool itself, gating irreversible actions. | MCP · GPT-4o-mini · Supabase · n8n |
| [competitor-intelligence](./competitor-intelligence/) | **Replaces a $100s/mo SaaS.** Tracks competitors daily, uses AI to surface *only what changed* (hash-diff keeps it cents/day), and ships a sectioned weekly brief + a RAG chat — across 3 businesses. | n8n · OpenAI · Supabase/pgvector · Slack |
| [whatsapp-lead-qualifier](./whatsapp-lead-qualifier/) | **No inbound lead goes cold.** Answers WhatsApp leads instantly 24/7, runs a full BANT qualification, saves state per phone (resumable), then routes hot leads to a booking link + Slack alert. | n8n · OpenAI · Supabase · WhatsApp · Slack |
| [whatsapp-task-relay](./whatsapp-task-relay/) | **The client's message *is* the task.** Reads inbound WhatsApp client requests, decides if it's even a real request (chit-chat filtered out), extracts a structured task — title, client, priority, budget/deadline intact — then alerts **Slack** and files it on a **Monday.com** board via GraphQL. No one re-types a request into the board again. | n8n · OpenAI · WhatsApp · Slack · Monday.com |
| [rag-support-chatbot](./rag-support-chatbot/) | **Support answers that don't hallucinate.** Auto-syncs a Google Drive folder into a vector store and answers *only* from those docs — cites the source file, refuses what isn't documented. | n8n · OpenAI · Supabase/pgvector · Google Drive |
| [social-content-bot](./social-content-bot/) | **Autoposting with a human gate.** Turns one idea into platform-tailored posts, self-critiques for quality, then *pauses* for Slack Approve/Decline before publishing — and logs the live link back. | n8n · OpenAI · Google Sheets · Slack · Ayrshare |
| [ai-email-triage](./ai-email-triage/) | **An inbox that sorts itself.** Classifies every email, then routes it — Slack-alerts the urgent, **drafts replies for review**, flags leads, files newsletters, bins spam — and tags each `triaged` so it's never handled twice. Nothing is sent without a human. | n8n · OpenAI · Gmail · Slack |
| [email-lead-qualifier](./email-lead-qualifier/) | **No inbound email lead goes cold.** Scores every email against BANT, routes it **hot / warm / dismiss**, captures leads to a database + tracker sheet, alerts Slack — and sends an instant, temperature-aware acknowledgment. The warm path captures *incomplete* inquiries instead of dropping them. | n8n · OpenAI · Supabase · Gmail · Slack · Sheets |
| [crm-lead-engine](./crm-lead-engine/) | **A CRM that cleans itself and captures every lead.** Two AI lanes on one **HubSpot** CRM: a scheduled agent that enriches + scores existing contacts (infers company/seniority from what's already there — no external data-append), and an inbound lane that qualifies emails, writes leads into HubSpot, routes by temperature, and auto-replies to hot/warm. | n8n · OpenAI · HubSpot · Gmail · Slack |
| [telegram-agent](./telegram-agent/) | **Hands-free assistant in Telegram.** Takes voice or text, transcribes with Whisper, and routes to tools for calendar, email, and web search — replying by text or audio. | n8n · GPT-4o · Telegram · Whisper |
| [shared-error-handler](./shared-error-handler/) | **The production-readiness layer.** One 3-node workflow that every other build points at — the moment *any* workflow fails, it formats the error (which workflow, which node, the message, a deep link to the failed run) and emails an alert instantly. Wired into every workflow in one pass via the n8n public API, so a silent failure becomes an inbox alert you can act on in seconds. | n8n · Gmail |

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

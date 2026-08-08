# HireFlow — Node-by-Node Walkthrough

Five workflows. Each section walks the nodes in execution order and calls out the *why*, not just the *what*.

---

## 1 · Resume Intake & Screening (`resume-intake.json`)

**Flow:** Form → Extract → Role lookup → Prompt → OpenAI → Normalize → Dedupe → Create → Acknowledge → Slack card

| Node | Type | What / why |
|------|------|------------|
| **HireFlow — Resume Intake** | Form Trigger | Public careers form; the résumé PDF arrives as a binary. |
| **Extract from File** | Extract From File | Pulls clean text from the PDF (handles column/table layouts) so the LLM sees the real content, not a blob. |
| **Search records** | Airtable | Loads **this role's** scorecard (must-haves, nice-to-haves, weights) from the Roles table. Data-driven: change the rubric in Airtable, not the workflow — that's the multi-role story. |
| **Build Prompt** | Set | Assembles the résumé text + scorecard into the screening prompt. |
| **OpenAI** | HTTP Request | `gpt-4o-mini` with a JSON response format. The system prompt scores against the scorecard and is told to judge **only job-relevant evidence** — ignore name, age, school dates, address, nationality. |
| **Normalize** | Code | Parses the structured JSON: `score`, `recommendation`, `must_have_hits/misses`, `red_flags`, `summary`, `reasoning`. The reasoning is stored as the audit trail. |
| **Search records1** + **If** | Airtable + If | **Dedupe** on email + role so re-submissions don't double-file. Only new candidates continue (the `If` false branch). |
| **Create a record** | Airtable | Writes the scored candidate to the Candidates table at **Stage = Screened**, with the full reasoning = audit log. |
| **Send a message** (Gmail) | Gmail | **The only auto-send in the whole system** — a neutral, score-blind acknowledgment to the applicant. |
| **Send a message1** (Slack) | Slack | Posts a Block Kit review card to the hiring channel: score, summary, misses, red flags + **Approve / Decline** buttons. Each button's `value` carries the candidate's record id + role + name + email so the callback is self-describing (no lookup needed later). |

> **Gotcha baked in:** Slack Block Kit with expressions fails if you paste raw JSON with inline `{{ }}` (nested quotes break the JSON). The blocks are built as a single `JSON.stringify({...})` expression so everything is escaped in one pass.

---

## 2 · Slack Actions — Human-in-the-Loop (`slack-actions.json`)

**Flow:** Webhook → Code → Switch → (Approve branch) / (Decline branch)

| Node | Type | What / why |
|------|------|------------|
| **Webhook** | Webhook (POST) | Receives the button click from Slack's Interactivity. Responds immediately — Slack requires a 200 within 3 seconds. |
| **Code** | Code | Slack posts `application/x-www-form-urlencoded`; the payload is a JSON string at `body.payload`. Parses it, then parses `actions[0].value` into `{recordId, role, name, email}` and keeps the `response_url` for updating the card. |
| **Switch** | Switch | Branches on `action_id`: **approve** (output 0) vs **decline** (output 1). There is deliberately no auto-reject path — a human clicked. |
| **Search records** | Airtable | *(Approve only)* fetches the role's booking link from the Roles table. |
| **Create a draft** / **Create a draft1** | Gmail | Prepares a **draft** — invite (with booking link) on approve, kind generic rejection (no link) on decline. Draft, never send: the human reviews and hits send. |
| **Update record** / **Update record1** | Airtable | Advances the ATS stage: **Interview** on approve, **Not proceeding** on decline. Only the Stage field is mapped so nothing else on the record is disturbed. |
| **HTTP Request** / **HTTP Request1** | HTTP Request | POSTs to the Slack `response_url` with `replace_original: true` — the card morphs in place to "✅ Approved by …" / "✕ Declined by …", removing the buttons (blocks double-clicks) and stamping who decided. |

---

## 3 · Onboarding Autopilot (`onboarding.json`)

**Flow:** Schedule → Search (Hired) → OpenAI → (Code → Create rows) + (Draft → Calendar → Flag)

| Node | Type | What / why |
|------|------|------------|
| **Schedule Trigger** | Schedule | Polls on an interval. Poll-not-push: it can't miss the moment someone is hired. |
| **Search records** | Airtable | Finds candidates where `Stage = Hired AND Onboarding Created = FALSE`. The checkbox is the idempotency guard. |
| **HTTP Request** | HTTP Request | `gpt-4o-mini` writes a role-specific onboarding checklist as structured JSON (IT provisioning, HR paperwork, manager 1:1s, role ramp, doc-required flags). |
| **Code in JavaScript** | Code | Explodes the checklist array into one n8n item per checklist entry, each carrying the candidate's name/email/role. |
| **Create a record** | Airtable | Writes each checklist item to the Onboarding table (owner, due day, **Doc Required** as a real boolean via expression — not a fixed toggle). |
| **Create a draft** (Gmail) → **Create an event** (Google Calendar) → **Update record** (Airtable) | — | **Branched off the candidate stream** (not the exploded rows) so these fire **once per hire**, not once per checklist item: a welcome-email draft, a Day-1 calendar event, then flip `Onboarding Created = true` so the next poll skips this hire. |

> **Gotcha baked in:** past the first node in a branch, `$json` refers to the *previous* node — references to the candidate use `$('Search records').item.json.*`, not `$json`, or you'd grab the calendar event's id instead of the candidate's record id.

---

## 4 · Document Chaser (`doc-chaser.json`)

**Flow:** Schedule → Search → Code → Draft

| Node | Type | What / why |
|------|------|------------|
| **Schedule Trigger** | Schedule | Daily sweep. |
| **Search records** | Airtable | Onboarding items where `Doc Required = true AND Status ≠ Done` — the paperwork still outstanding. |
| **Code in JavaScript** | Code | Groups outstanding items **by candidate** so each person gets one reminder listing everything they owe — not one email per item. |
| **Create a draft** | Gmail | A polite **draft** reminder per candidate, listing only the missing documents. Draft, never auto-sent. |

---

## 5 · Weekly HR Brief (`weekly-brief.json`)

**Flow:** Schedule → Search (Candidates) → Candidate Stats → Search (Onboarding) → Combine → OpenAI → Send

| Node | Type | What / why |
|------|------|------------|
| **Schedule Trigger** | Schedule | Weekly. |
| **Search 1** | Airtable | Pulls the whole Candidates pipeline. |
| **Candidate Stats** | Code | Run once for **all** items: totals by role/stage, shortlist rate, and stale candidates (created >7 days ago, still New/Screened). Collapses to a single stats item. |
| **Search** | Airtable | Pulls the Onboarding table (runs once, because the previous node already collapsed to one item). |
| **Combine** | Code | Adds outstanding-document count and merges the candidate metrics into one object. **This single-item collapse is what stops the brief from sending once per row.** |
| **HTTP Request** | HTTP Request | `gpt-4o-mini` turns the metrics into a concise, friendly brief (prose, not JSON). |
| **Send a message** | Gmail | Sends the brief to the owner. Internal report, so this one sends rather than drafts. |

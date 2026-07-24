# Shared Error Handler — one failure notifier for every workflow

**A workflow that runs perfectly in the demo and fails silently in production isn't finished.**
The Shared Error Handler is the production-readiness layer for this whole portfolio: a single
3-node workflow that every other workflow points at, so the moment *any* of them fails, a readable
alert lands in the inbox — which workflow, which node, the error, and a one-click link to the
failed run.

Build it once. Wire it everywhere. Every build inherits failure alerting for free.

> 📖 **[WALKTHROUGH.md](WALKTHROUGH.md)** explains every node, line by line.

---

## Why this exists

**The problem —** an automation you can't see failing is worse than no automation, because you
*trust* it. A webhook starts 500-ing, an API token expires, an LLM returns malformed JSON — and
the workflow just stops. No one notices until a customer does. Wiring bespoke error handling into
every workflow individually is tedious enough that it never gets done, which is exactly why so many
otherwise-good automations are one silent failure away from an incident.

**The result —** every workflow in this repo now reports its own failures automatically, through
one shared handler. A failure becomes an email you can act on in seconds, not a mystery you
discover days later.

---

## What it does

- **Catches** the failure of any workflow that names it as their Error Workflow — via n8n's
  built-in **Error Trigger**.
- **Formats** the raw error payload into one readable alert: the failed workflow, the node that
  broke, the error message, a timestamp, and a **deep link to the exact failed run**.
- **Notifies** instantly by email, with the workflow name **in the subject** so failures are
  triageable straight from the inbox — no need to open the message.
- **Scales to the whole portfolio** — it's completely generic. One handler serves every build;
  adding a new workflow is one setting, not a new error-handling pipeline.

---

## Architecture

One workflow, three nodes.

```
Error Trigger  →  Edit Fields   →  Send a message
(catch failure)   (format alert)   (Gmail)
```

Every *other* workflow references it through a single setting:

```
<any workflow> ─ Settings → Error Workflow ─▶ Shared Error Handler
```

### The design decisions that matter

| Choice | Why |
|---|---|
| **One generic handler, referenced by every workflow** | Bespoke per-workflow error handling never gets built. A single shared workflow + a one-field setting gives the whole portfolio alerting, and a new build inherits it for free. |
| **Format the payload, don't forward it** | The value is in the alert being *human*. Four fields — workflow, node, error, run-link — beats a raw JSON dump you'll ignore. |
| **Workflow name in the subject line** | You can triage from the inbox list without opening anything. `🚨 n8n failure: CashChaser` tells you what broke at a glance. |
| **Wired via the n8n public API, not the CLI importer** | The CLI import path can silently *deactivate* Published workflows. `PUT /workflows/{id}` with `settings.errorWorkflow` sets the reference while leaving `active` untouched — every live workflow stayed live. |
| **Gmail is just the last node** | Swap it for Slack or Telegram and the trigger + formatter are unchanged. The channel is a detail; the pattern is the point. |

---

## Tech stack

- **n8n** (self-hosted) — orchestration + the Error Trigger
- **Gmail** — the alert channel (swappable for Slack / Telegram)

---

## Setup

1. **Import the workflow:** [`workflows/shared-error-handler.json`](workflows/shared-error-handler.json)

2. **Point the alert somewhere real.** On the **Send a message** (Gmail) node, replace the
   placeholder recipient `alerts@your-domain.com` with your own address, and connect a Gmail
   credential. Attribution footer is already off for clean mail.

3. **Wire it into your workflows.** On each workflow you want covered:
   **Settings → Error Workflow → Shared Error Handler**. That single reference is what routes that
   workflow's production failures here.
   > To do it in bulk across many workflows, set `settings.errorWorkflow` to this workflow's ID via
   > the n8n public API (`PUT /workflows/{id}`) rather than clicking through each one. Use the API,
   > not the CLI importer — the importer can deactivate Published workflows.

4. **Prove it works** without breaking anything: open the handler, feed the **Error Trigger** mock
   data shaped like a real failure (an `execution` object with `error.message`, `lastNodeExecuted`,
   `url`, plus a `workflow` object with `name`), and **Execute workflow**. The alert email sends.
   Error workflows only fire on *production* failures, so this mock run is how you test the notify
   path directly.

---

## Security notes

- **No secrets in this repo.** n8n exports *reference* credentials by name — never keys or tokens.
- **Placeholder recipient** — the alert address is scrubbed to `alerts@your-domain.com`.
- **No payload data.** The handler only ever formats the failure metadata n8n hands it at runtime;
  nothing sensitive is stored in the workflow.

---

## Results & highlights

- **Portfolio-wide coverage in one pass** — wired into every workflow via the public API, with
  zero unintended deactivations of the live/Published ones.
- **Failures are now visible** — a broken workflow emails you within seconds, with a direct link to
  the failed run, instead of stopping silently.
- **Trivial to extend** — a new build gets alerting by setting one field, not by rebuilding error
  handling from scratch.

---

## Roadmap

- **Severity routing** — Slack for anything touching a live customer flow, email for the rest.
- **Auto-retry before alerting** — pair with per-node *Retry On Fail* so transient blips
  self-heal and only real failures page you.
- **Failure log** — append every alert to a Sheet/Postgres table for a running reliability view
  across all workflows.

---

## License

MIT — see `LICENSE` (add your preferred license file).

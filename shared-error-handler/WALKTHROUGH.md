# Build Walkthrough — node by node

How the Shared Error Handler works, explained so you can read and present it. It's a single,
tiny workflow that every *other* workflow points at. When any of them fails in production, n8n
routes the failure here, which turns the raw error into a readable alert and emails it instantly.

> n8n note: an **Error Trigger** is a special start node that fires when *another* workflow — one
> that names this workflow in its **Settings → Error Workflow** — finishes with an error. It's not
> triggered by this workflow's own runs; it's the catch-all for everyone else's failures.

```
Error Trigger ─▶ Edit Fields ─▶ Send a message
(catch failure)  (format alert)  (email it)
```

**1. Error Trigger** — the entry point. It fires automatically whenever a workflow that references
this one fails. It receives a rich payload describing the failure, including:

- `{{ $json.workflow.name }}` — which workflow failed
- `{{ $json.execution.lastNodeExecuted }}` — the node that actually broke
- `{{ $json.execution.error.message }}` — the error text
- `{{ $json.execution.url }}` — a deep link straight to the failed run

**2. Edit Fields** (Set) — the formatter. It collapses that payload into one readable `alert`
string — a headline, the failing node, the error, a timestamp, and the one-click link to open the
failed execution. This is the difference between an alert a human can act on and a raw JSON dump:

```
🚨 Workflow failed: <name>

Node:  <node that broke>
Error: <error message>
Time:  <ISO timestamp>

Open the failed run: <deep link>
```

**3. Send a message** (Gmail) — the notifier. It emails the alert instantly. The failed workflow's
name is put **in the subject line** (`🚨 n8n failure: <name>`) so failures are triageable straight
from the inbox list — you can see *what* broke without opening the message. n8n's attribution
footer is turned off for clean, client-ready mail.

> ⚠️ **Design choice — one handler, wired everywhere.** This workflow is deliberately generic. It
> knows nothing about any specific build. Every other workflow simply names it as its Error
> Workflow, so a single 3-node flow gives the *entire* portfolio production-grade failure alerting.
> Add a new build, point its Error Workflow setting here, and it inherits the alerting for free.

## How it gets wired

Each workflow carries an `errorWorkflow` reference in its **Settings**. Setting it (in the UI:
**Settings → Error Workflow → Shared Error Handler**) is what tells n8n to route that workflow's
failures here. Across this portfolio it was applied to every workflow in one pass via the n8n
**public API** (`PUT /workflows/{id}` with `settings.errorWorkflow`), rather than clicking through
each one by hand.

## Gotchas & lessons

- **Error workflows fire on *production* failures, not manual test runs.** To prove the notify
  path without breaking a real workflow, feed the Error Trigger mock data shaped like the real
  payload (`execution` + `workflow` objects) and execute — the email still sends.
- **Wire via the API, not the CLI importer.** n8n's CLI import can silently *deactivate* Published
  workflows; the public API `PUT` sets the error-workflow reference while leaving `active`
  untouched. Every active workflow stayed active through the bulk wiring.
- **Keep the alert human.** The value of an error handler is in the formatting — surface the four
  things you actually need (which workflow, which node, what error, a link to the run) and nothing
  else. A raw payload in your inbox gets ignored.
- **Swap the channel, keep the chain.** Gmail is just the last node. Replace it with Slack or
  Telegram and the trigger + formatter are unchanged — the alerting stays identical.

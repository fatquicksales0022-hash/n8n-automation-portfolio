-- Query used by the `upsert_lead` tool — a Postgres node attached to the AI Agent
-- as a tool (Operation: Execute Query). The agent calls it as it learns each fact;
-- the values arrive from the model via $fromAI(...).
--
-- Two design choices make it robust against a chatty, partial-information agent:
--   * ON CONFLICT (phone)  -> exactly one stable row per lead (keyed by phone),
--                             so every turn updates the same record.
--   * COALESCE(EXCLUDED.x, leads.x) with NULLIF on insert -> a partial update
--                             never wipes a field that's already known. Empty
--                             values become NULL and are simply ignored.
--
-- The phone (the lead key) comes from the workflow (Edit Fields), NOT from the LLM
-- — you never let the model invent your primary key. The $fromAI enum hints keep
-- authority / timeline / stage clean without needing CHECK constraints.

INSERT INTO leads (phone, name, company, budget, authority, need, timeline, score, stage, updated_at)
VALUES (
  '{{ $('Edit Fields').item.json.phone }}',
  NULLIF('{{ $fromAI("name") }}', ''),
  NULLIF('{{ $fromAI("company") }}', ''),
  NULLIF('{{ $fromAI("budget") }}', ''),
  NULLIF('{{ $fromAI("authority", "exactly one of: decision_maker, influencer, unknown") }}', ''),
  NULLIF('{{ $fromAI("need") }}', ''),
  NULLIF('{{ $fromAI("timeline", "exactly one of: now, this_quarter, later, unknown") }}', ''),
  NULLIF('{{ $fromAI("score") }}', '')::int,
  NULLIF('{{ $fromAI("stage", "exactly one of: new, qualifying, qualified, disqualified") }}', ''),
  now()
)
ON CONFLICT (phone) DO UPDATE SET
  name      = COALESCE(EXCLUDED.name,      leads.name),
  company   = COALESCE(EXCLUDED.company,   leads.company),
  budget    = COALESCE(EXCLUDED.budget,    leads.budget),
  authority = COALESCE(EXCLUDED.authority, leads.authority),
  need      = COALESCE(EXCLUDED.need,      leads.need),
  timeline  = COALESCE(EXCLUDED.timeline,  leads.timeline),
  score     = COALESCE(EXCLUDED.score,     leads.score),
  stage     = COALESCE(EXCLUDED.stage,     leads.stage),
  updated_at = now();

-- ============================================================================
--  upsert_lead tool query — EXPLAINED line by line
-- ============================================================================
--  The AI Agent calls this (a Postgres node attached as a "tool") every time it
--  learns a fact about the lead. Same query as upsert-lead-tool.sql, annotated.
--
--  KEY MENTAL MODEL: the {{ ... }} parts are n8n templating, NOT SQL. n8n fills
--  them with real values BEFORE the query reaches Postgres. By the time the
--  database runs this, every {{ }} is already a plain literal value.

INSERT INTO leads (phone, name, company, budget, authority, need, timeline, score, stage, updated_at)
-- ^ start a new row; list the columns we'll fill, in this order.

VALUES (
  '{{ $('Edit Fields').item.json.phone }}',
  -- ^ the phone comes from the WORKFLOW (the Edit Fields node), NOT the AI.
  --   You never let the model invent your primary key. Single quotes = SQL text.

  NULLIF('{{ $fromAI("name") }}', ''),
  -- ^ $fromAI("name") = the value the MODEL learned for "name".
  --   NULLIF(x, '') = "if x is an empty string, store NULL instead." The agent
  --   calls this every turn, often with blanks for facts it doesn't know yet —
  --   NULLIF stops a blank from being treated as a real value.

  NULLIF('{{ $fromAI("company") }}', ''),
  NULLIF('{{ $fromAI("budget") }}', ''),

  NULLIF('{{ $fromAI("authority", "exactly one of: decision_maker, influencer, unknown") }}', ''),
  -- ^ the 2nd argument to $fromAI is a HINT to the model: "only output one of
  --   these values." It keeps the column clean WITHOUT a CHECK constraint that
  --   could crash the insert (the prompt-layer validation discussed in the schema).

  NULLIF('{{ $fromAI("need") }}', ''),
  NULLIF('{{ $fromAI("timeline", "exactly one of: now, this_quarter, later, unknown") }}', ''),

  NULLIF('{{ $fromAI("score") }}', '')::int,
  -- ^ same NULLIF trick, then ::int converts the text into a whole number,
  --   because `score` is an integer column.

  NULLIF('{{ $fromAI("stage", "exactly one of: new, qualifying, qualified, disqualified") }}', ''),
  now()                              -- updated_at = the current time
)

ON CONFLICT (phone) DO UPDATE SET
-- ^ THE UPSERT (insert-or-update). "If a row with this phone ALREADY exists
--   (a conflict on the primary key), don't error and don't make a duplicate —
--   UPDATE the existing row instead." This is what lets a returning lead update
--   their own record rather than spawning a second one.

  name      = COALESCE(EXCLUDED.name,      leads.name),
  -- EXCLUDED.name = the NEW value we just tried to insert.
  -- leads.name    = the value ALREADY in the table.
  -- COALESCE(a, b) = "use a if it isn't NULL, otherwise use b."
  -- => if the AI gave a new name, use it; if it gave nothing (NULL), KEEP the old name.
  --    THIS is the line that means a partial update never erases data you already had.

  company   = COALESCE(EXCLUDED.company,   leads.company),
  budget    = COALESCE(EXCLUDED.budget,    leads.budget),
  authority = COALESCE(EXCLUDED.authority, leads.authority),
  need      = COALESCE(EXCLUDED.need,      leads.need),
  timeline  = COALESCE(EXCLUDED.timeline,  leads.timeline),
  score     = COALESCE(EXCLUDED.score,     leads.score),
  stage     = COALESCE(EXCLUDED.stage,     leads.stage),
  updated_at = now();                -- always refresh the "last updated" stamp

-- In one sentence:
--   "Save this lead — create them if new, update them if we've seen them before,
--    only overwrite a field when we actually learned something new, and never
--    wipe what we already knew."

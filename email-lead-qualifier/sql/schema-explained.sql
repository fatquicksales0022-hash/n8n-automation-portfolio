-- ============================================================================
--  Email Lead Qualifier — schema + upsert, explained
--  A heavily-commented, still-runnable reference. Run schema.sql for the clean
--  version; read this one to understand the WHY.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------
create table if not exists public.email_leads (
  email      text primary key,   -- The lead key comes from the EMAIL SENDER, never
                                  -- from the LLM. A primary key is required so the
                                  -- workflow can UPSERT (INSERT ... ON CONFLICT).
  name       text,
  company    text,
  -- Every BANT field is plain TEXT, deliberately. The Information Extractor returns
  -- free-form strings ("around $8-10k", "2-3 weeks", "unknown"). A CHECK constraint
  -- or an enum would reject those and crash the whole insert. We store the model's
  -- words as-is and let the `stage` + `score` columns carry the structured signal.
  budget     text,
  authority  text,
  need       text,
  timeline   text,
  score      int,     -- 0–100 BANT fit, computed by the model against a fixed rubric.
  stage      text,    -- 'qualified' (act now) | 'unclear' (nurture) | 'not_qualified'.
  summary    text,
  subject    text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.email_leads enable row level security;

-- ---------------------------------------------------------------------------
-- The upsert (this lives in the two "Execute a SQL query" nodes, shown here so
-- you can read it outside the workflow). Values arrive as parameters $1..$11.
-- ---------------------------------------------------------------------------
--   INSERT INTO email_leads
--     (email, name, company, budget, authority, need, timeline,
--      score, stage, summary, subject, updated_at)
--   VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now())
--   ON CONFLICT (email) DO UPDATE SET
--     name      = COALESCE(NULLIF(EXCLUDED.name,''),      email_leads.name),
--     company   = COALESCE(NULLIF(EXCLUDED.company,''),   email_leads.company),
--     budget    = COALESCE(NULLIF(EXCLUDED.budget,''),    email_leads.budget),
--     authority = COALESCE(NULLIF(EXCLUDED.authority,''), email_leads.authority),
--     need      = COALESCE(NULLIF(EXCLUDED.need,''),      email_leads.need),
--     timeline  = COALESCE(NULLIF(EXCLUDED.timeline,''),  email_leads.timeline),
--     score     = EXCLUDED.score,
--     stage     = EXCLUDED.stage,
--     summary   = EXCLUDED.summary,
--     subject   = EXCLUDED.subject,
--     updated_at = now();
--
--   Why COALESCE(NULLIF(EXCLUDED.x,''), email_leads.x)?
--   If the same person emails again and the new message omits a field (empty string),
--   we KEEP the value we already learned instead of blanking it. score/stage/summary
--   always take the newest read, because those reflect the latest message.
--
--   Parameters are passed as an ARRAY (n8n "Query Parameters"), never string-concat,
--   so apostrophes in `need`/`summary` (e.g. "I'd like...") can't break the SQL.

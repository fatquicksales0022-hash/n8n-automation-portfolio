-- ============================================================================
--  leads table — EXPLAINED line by line
-- ============================================================================
--  Same schema as schema.sql, annotated so you can read (and explain) exactly
--  what every line does. Run the clean `schema.sql` for the actual setup.

create table if not exists public.leads (   -- make the table; "if not exists" = safe to re-run
  phone       text primary key,              -- the phone number IS the unique lead id:
                                             --   * no two leads can share it
                                             --   * it can never be empty (NULL)
                                             --   * it's what the upsert keys off -> one row per lead
  name        text,                          -- plain text; may be empty (NULL) until the agent learns it
  company     text,                          --   "
  budget      text,                          -- TEXT, not a number — so it can hold ranges like "$10k-25k"
  authority   text,                          -- who decides: decision_maker | influencer | unknown
  need        text,                          -- what they want help with
  timeline    text,                          -- when: now | this_quarter | later | unknown
  score       integer default 0,             -- whole number 0-100; "default 0" = starts at 0 if none given
  stage       text default 'new',            -- funnel stage; a new lead defaults to 'new'
  created_at  timestamptz default now(),     -- timestamp WITH timezone; set once, auto-filled with now()
  updated_at  timestamptz default now()      -- last-updated stamp; we bump it on every write (see upsert)
);

-- Row Level Security: with RLS on, the table is BLOCKED from the public API by
-- default. n8n connects as the privileged `postgres` user, which BYPASSES RLS,
-- so the workflow keeps working — but nobody using Supabase's public/anon key can
-- read your leads. One-liner: "the table is backend-only."
alter table public.leads enable row level security;


-- ----------------------------------------------------------------------------
--  Why authority / timeline / stage are plain text and NOT CHECK enums
-- ----------------------------------------------------------------------------
--  A first version used CHECK constraints to force those columns to a fixed set
--  of values. But an LLM occasionally emits free text ("Yourself", "2 weeks"),
--  which VIOLATES the rule and crashes the entire INSERT — killing the live
--  conversation. These are the statements that removed them
--  ("if exists" = don't error if the constraint is already gone):
--
--      alter table public.leads drop constraint if exists leads_authority_check;
--      alter table public.leads drop constraint if exists leads_timeline_check;
--      alter table public.leads drop constraint if exists leads_stage_check;
--      alter table public.leads drop constraint if exists leads_score_check;
--
--  The lesson: validation moved OUT of the database and INTO the prompt (the
--  agent is told the allowed values via $fromAI hints — see upsert-lead-explained.sql).
--  A resilient agent beats a strict-but-brittle schema.


-- ----------------------------------------------------------------------------
--  A note on whatsapp_memory (the chat-memory table)
-- ----------------------------------------------------------------------------
--  There's no CREATE TABLE for it on purpose: n8n's "Postgres Chat Memory" node
--  creates `whatsapp_memory` automatically on first run. It stores the running
--  dialogue keyed by session id (= the phone number), so the agent remembers the
--  conversation across messages and even after a restart.

-- Email Lead Qualifier — Supabase / Postgres schema
-- One table: the deduped current state of every captured lead (keyed on email).

create table if not exists public.email_leads (
  email      text primary key,           -- PK required for the ON CONFLICT upsert
  name       text,
  company    text,
  budget     text,                        -- all BANT fields are TEXT on purpose:
  authority  text,                        -- the LLM returns free text, and a CHECK
  need       text,                        -- constraint would crash the insert the
  timeline   text,                        -- moment it sends something unexpected.
  score      int,                         -- BANT fit, 0–100
  stage      text,                         -- 'qualified' | 'unclear' | 'not_qualified'
  summary    text,
  subject    text,                         -- originating email subject, for context
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.email_leads enable row level security;
-- The workflow writes via a direct Postgres connection (role: postgres), which
-- bypasses RLS — so no policies are needed for the automation itself. Add policies
-- only if you expose this table through the Supabase REST / anon API.

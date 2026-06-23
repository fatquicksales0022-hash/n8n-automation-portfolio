-- WhatsApp Lead Qualification Agent — Supabase schema
-- Run this in the Supabase SQL Editor.
-- n8n connects over the Supabase Session Pooler with a Postgres credential; RLS
-- stays enabled (the postgres/service_role user bypasses it), so the tables are
-- backend-only while every node keeps working.

-- Structured lead state. ONE row per lead, keyed by phone number — so a lead can
-- leave mid-conversation and resume days later with everything remembered.
create table if not exists public.leads (
  phone       text primary key,        -- the lead's WhatsApp number = the lead key
  name        text,
  company     text,
  budget      text,                     -- free text, e.g. "$10k-25k"
  authority   text,                     -- decision_maker | influencer | unknown
  need        text,
  timeline    text,                     -- now | this_quarter | later | unknown
  score       integer default 0,        -- running BANT score, 0-100
  stage       text default 'new',       -- new | qualifying | qualified | disqualified
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table public.leads enable row level security;

-- Why authority / timeline / stage are plain text (not CHECK enums):
-- the valid values are enforced at the *prompt* layer instead (the agent is told
-- the allowed values via $fromAI hints — see sql/upsert-lead-tool.sql). An LLM
-- occasionally emits free text ("2 weeks" instead of "this_quarter"); a hard CHECK
-- constraint would reject the whole insert and break the live conversation.
-- Text columns + prompt-level guidance keep the agent resilient.

-- The chat-memory table (`whatsapp_memory`) is created AUTOMATICALLY by n8n's
-- "Postgres Chat Memory" node on first run — no DDL needed here. It stores the
-- running dialogue keyed by session id (the phone number), so the agent remembers
-- across messages and even after a restart.

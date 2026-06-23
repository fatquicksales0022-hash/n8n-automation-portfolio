-- notes table for the MCP personal assistant's memory store
-- Run this in Supabase → SQL Editor → New query → Run

create table public.notes (
  id          bigint generated always as identity primary key,
  content     text        not null,
  tags        text,
  created_at  timestamptz not null default now()
);

-- Lock the table down: only the service_role key (used by n8n) can touch it.
-- The public/anon keys are blocked. n8n still works because service_role
-- bypasses RLS.
alter table public.notes enable row level security;

-- Competitor Intelligence System — Supabase schema
-- Run this in the Supabase SQL Editor. Choose "Run and enable RLS" when prompted;
-- n8n connects with the service_role key, which bypasses RLS, so the tables stay
-- backend-only while every node keeps working.

-- 1. pgvector extension (for semantic search)
create extension if not exists vector;

-- 2. Watch list: the competitors to track, plus the change-detection memory.
--    `brand` makes this multi-tenant — one pipeline serving several businesses.
create table if not exists competitors (
  id          bigserial primary key,
  brand       text,                  -- which business this competitor belongs to
  competitor  text not null,
  url         text not null unique,  -- RSS / Google News / YouTube feed URL
  type        text not null check (type in ('rss','page','js')),
  last_hash   text,                  -- SHA-256 of last-seen content (the diff key)
  last_text   text,                  -- last-seen content (so the LLM can diff)
  updated_at  timestamptz default now()
);

-- 3. Vector store for change summaries.
--    1536 dims = OpenAI text-embedding-3-small. Powers the chat/RAG layer.
create table if not exists competitor_intel (
  id        bigserial primary key,
  content   text,
  metadata  jsonb,
  embedding vector(1536)
);

-- 4. Relational log of changes — feeds the weekly digest (easy to query by date).
create table if not exists intel_log (
  id           bigserial primary key,
  brand        text,
  competitor   text,
  url          text,
  change_type  text,
  significance text,
  summary      text,
  implication  text,
  created_at   timestamptz default now()
);

-- 5. Similarity-search function for the chat/RAG layer.
--    Every column is table-qualified on purpose: without it, Postgres throws
--    42702 ("column reference 'id' is ambiguous") because the RETURNS TABLE
--    column names collide with the table's own columns.
create or replace function match_competitor_intel (
  query_embedding vector(1536),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
) language plpgsql as $$
begin
  return query
  select
    competitor_intel.id,
    competitor_intel.content,
    competitor_intel.metadata,
    1 - (competitor_intel.embedding <=> query_embedding) as similarity
  from competitor_intel
  where competitor_intel.metadata @> filter
  order by competitor_intel.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 6. Example watch list — swap these for your own competitors.
--    type='rss' works out of the box. For sites without a feed, Google News RSS
--    works for any company:
--    https://news.google.com/rss/search?q=%22Company+Name%22&hl=en-US&gl=US&ceid=US:en
insert into competitors (brand, competitor, url, type) values
  ('Brand A', 'TechCrunch', 'https://techcrunch.com/feed/',           'rss'),
  ('Brand A', 'The Verge',  'https://www.theverge.com/rss/index.xml', 'rss')
on conflict (url) do nothing;

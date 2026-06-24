-- ============================================================================
--  Competitor Intelligence System — schema, EXPLAINED line by line
--
--  Same schema as schema.sql, annotated as a learning reference.
--  It is still valid SQL: you can run this file as-is in the Supabase SQL Editor.
-- ============================================================================


-- ── pgvector extension ──────────────────────────────────────────────────────
-- Adds the `vector` data type + similarity operators (needed for embeddings).
-- `if not exists` = don't error if it's already enabled.
create extension if not exists vector;


-- ── Table 1: competitors — the watch list + change-detection memory ─────────
create table if not exists competitors (
  -- Auto-incrementing ID, the primary key. `bigserial` = auto-incrementing bigint.
  id          bigserial primary key,
  -- Which of your businesses this competitor belongs to (the multi-tenant tag).
  brand       text,
  -- The competitor's name. `not null` = required, can't be empty.
  competitor  text not null,
  -- The feed URL. `unique` = no two rows share a url; also lets the crawl
  -- find-and-update a competitor by matching on url.
  url         text not null unique,
  -- Source type. The `check (...)` constraint allows ONLY these three values
  -- and rejects anything else at insert time.
  type        text not null check (type in ('rss','page','js')),
  -- SHA-256 fingerprint of the last-seen content — the key to change detection.
  last_hash   text,
  -- The last-seen content text, so the LLM can diff old vs new.
  last_text   text,
  -- Last-touched timestamp; `default now()` auto-sets it on insert.
  updated_at  timestamptz default now()
);


-- ── Table 2: competitor_intel — the vector store (powers the chat/RAG) ──────
create table if not exists competitor_intel (
  id        bigserial primary key,   -- auto ID
  content   text,                     -- the text that was embedded (the summary)
  metadata  jsonb,                    -- flexible JSON: competitor, brand, date, …
  embedding vector(1536)              -- 1536 dims = OpenAI text-embedding-3-small
);


-- ── Table 3: intel_log — plain relational log (feeds the weekly digest) ─────
create table if not exists intel_log (
  id           bigserial primary key,   -- auto ID
  brand        text,                      -- business tag
  competitor   text,                      -- competitor name
  url          text,                      -- source url
  change_type  text,                      -- pricing | product | messaging | …
  significance text,                      -- high | medium | low
  summary      text,                      -- one-line summary of the change
  implication  text,                      -- what it could mean for us
  created_at   timestamptz default now()  -- when it was logged
);


-- ── Similarity-search function (the chat agent's search tool calls this) ────
-- `create or replace` = create it, or overwrite it if it already exists.
create or replace function match_competitor_intel (
  query_embedding vector(1536),       -- input: the embedding of the user's question
  match_count     int   default null, -- how many rows to return (null = no limit)
  filter          jsonb default '{}'  -- optional metadata filter ({} = match all)
)
-- The shape of the rows this function returns:
returns table (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
-- Body is written in PL/pgSQL. The $$ ... $$ "dollar quotes" wrap the body so
-- you don't have to escape the quotes inside it.
language plpgsql as $$
begin
  return query
  select
    -- Columns are TABLE-QUALIFIED (competitor_intel.id, not bare id) ON PURPOSE:
    -- without the prefix, Postgres can't tell the table's column from the
    -- function's return column and throws error 42702 ("column is ambiguous").
    competitor_intel.id,
    competitor_intel.content,
    competitor_intel.metadata,
    -- `<=>` is pgvector's cosine DISTANCE (0 = identical, bigger = more different).
    -- `1 - distance` flips it into a SIMILARITY score (1 = identical).
    1 - (competitor_intel.embedding <=> query_embedding) as similarity
  from competitor_intel
  -- `@>` is the JSON "contains" operator: keep rows whose metadata contains the
  -- filter. With the default empty {} filter, every row passes.
  where competitor_intel.metadata @> filter
  -- Sort by distance ascending = closest / most similar first.
  order by competitor_intel.embedding <=> query_embedding
  -- Return at most match_count rows (the top-k results).
  limit match_count;
end;
$$;


-- ── Seed / UPSERT: example watch list (swap for your own competitors) ───────
-- INSERT listing 4 columns; id / last_hash / last_text / updated_at auto-fill.
insert into competitors (brand, competitor, url, type) values
  ('Brand A', 'TechCrunch', 'https://techcrunch.com/feed/',           'rss'),
  ('Brand A', 'The Verge',  'https://www.theverge.com/rss/index.xml', 'rss')
-- If a row with the same `url` already exists (url is UNIQUE), skip it instead
-- of erroring. "INSERT ... ON CONFLICT ... DO NOTHING" is the upsert pattern —
-- it makes this seed safe to run more than once.
on conflict (url) do nothing;

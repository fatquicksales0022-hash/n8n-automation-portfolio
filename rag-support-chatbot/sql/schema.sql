-- RAG Customer-Support Chatbot — Supabase schema
-- Run this in the Supabase SQL Editor BEFORE importing the workflows.
--
-- One table (`documents`) holds the chunked, embedded support docs. Both
-- workflows share it: the ingestion workflow WRITES, the chatbot READS.
--
-- IMPORTANT — the vector dimension MUST match your embedding model:
--   OpenAI text-embedding-3-small ............. 1536   (used here)
--   Google text-embedding-004 / Ollama nomic ... 768
-- A mismatch returns silently-wrong retrievals, so this is the #1 thing to check.

-- pgvector adds the `vector` column type + similarity operators (<=> = cosine distance).
create extension if not exists vector;

-- The knowledge base: one row per chunk.
create table if not exists public.documents (
  id        uuid primary key default gen_random_uuid(),
  content   text,                  -- the chunk text the model reads
  metadata  jsonb,                 -- { fileId, fileName, loc, ... } — powers citations + dedup
  embedding vector(1536)           -- 1536 = OpenAI text-embedding-3-small
);

-- Similarity search used by the chatbot's `search_docs` tool.
-- Every column is table-qualified to avoid Postgres error 42702
-- ("column reference 'id' is ambiguous"): the RETURNS TABLE column names
-- collide with the table's own columns otherwise.
create or replace function match_documents (
  query_embedding vector(1536),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id uuid,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where documents.metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

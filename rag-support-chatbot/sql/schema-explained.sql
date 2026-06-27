-- ============================================================================
-- RAG Customer-Support Chatbot — schema, EXPLAINED
-- ----------------------------------------------------------------------------
-- This is the same schema as schema.sql, annotated as a learning reference.
-- It is still runnable. Run it once in the Supabase SQL Editor.
--
-- The whole build rests on one idea: turn documents into vectors (lists of
-- numbers that capture meaning), store them, and at query time find the chunks
-- whose vectors are *closest* to the question's vector. That "closeness" search
-- is what `pgvector` adds to Postgres.
-- ============================================================================


-- 1) ENABLE pgvector ----------------------------------------------------------
-- Adds the `vector` data type and the distance operators. `<=>` is cosine
-- distance (0 = identical direction, 2 = opposite). We turn it into a 0..1
-- "similarity" score below with  1 - distance.
create extension if not exists vector;


-- 2) THE KNOWLEDGE BASE -------------------------------------------------------
-- One row per *chunk*, not per file. A 600-word doc becomes ~2 rows because the
-- ingestion workflow splits text into ~800-character chunks (100 overlap) before
-- embedding. Smaller chunks = more precise retrieval + smaller prompts.
create table if not exists public.documents (
  id        uuid primary key default gen_random_uuid(),

  -- The chunk's text. This is what actually gets fed to the LLM when retrieved.
  content   text,

  -- Arbitrary JSON tags attached to each chunk by the Data Loader. We store:
  --   fileId   -> the Google Drive file id (lets us dedup / delete by file)
  --   fileName -> e.g. "account-billing.txt" (lets the bot CITE its source)
  --   loc      -> which lines of the original file this chunk came from
  metadata  jsonb,

  -- The embedding. 1536 numbers, because that's the size OpenAI's
  -- text-embedding-3-small produces. IF YOU CHANGE THE EMBEDDING MODEL, change
  -- this number to match (e.g. 768 for Gemini text-embedding-004) or retrieval
  -- silently breaks.
  embedding vector(1536)
);


-- 3) THE SIMILARITY SEARCH FUNCTION ------------------------------------------
-- n8n's Supabase Vector Store node (in "retrieve" mode) calls this function.
-- It takes the question's embedding and returns the closest chunks.
--
-- WHY every column is prefixed with `documents.`:
-- the RETURNS TABLE below declares columns named id/content/metadata, which have
-- the SAME names as the table's columns. Unqualified, Postgres throws
--   42702: column reference "id" is ambiguous
-- Qualifying every reference (documents.id, documents.embedding, ...) removes
-- the ambiguity. (Hard-won lesson — same fix applies to any pgvector match fn.)
create or replace function match_documents (
  query_embedding vector(1536),         -- the question, embedded with the SAME model
  match_count int default null,         -- how many chunks to return (top-k; we use 5)
  filter jsonb default '{}'             -- optional metadata filter, e.g. {"fileName":"x"}
) returns table (
  id uuid,
  content text,
  metadata jsonb,
  similarity float                      -- 1 = perfect match, ~0 = unrelated
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
  where documents.metadata @> filter                 -- @> = "jsonb contains"
  order by documents.embedding <=> query_embedding    -- nearest first (smallest distance)
  limit match_count;
end;
$$;


-- 4) NOTE ON DEDUP (handled in the workflow, not here) ------------------------
-- The ingestion workflow re-scans the whole Drive folder on each run. To avoid
-- piling up duplicate chunks, the FIRST node after the schedule runs:
--     DELETE FROM documents;
-- ...then it re-inserts everything currently in the folder. That keeps the table
-- a clean mirror of the folder (and even handles files you DELETE from Drive).
-- For a large corpus you'd instead delete per-file by metadata->>'fileId' before
-- each insert; for a small support folder, wipe-and-reload is simplest + safest.

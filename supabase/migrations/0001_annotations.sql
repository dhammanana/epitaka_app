-- ============================================================================
-- 0001_annotations.sql — ePitaka annotation sync (highlights, notes, bookmarks)
--
-- Run this in the Supabase SQL editor (Dashboard → SQL → New query).
--
-- After running, ALSO whitelist the native redirect URL for Google OAuth:
--   Dashboard → Authentication → URL Configuration → Redirect URLs
--   add:  epitaka://login-callback/
-- and configure the Google provider (Authentication → Providers → Google)
-- with your Google OAuth Client ID/Secret.
-- ============================================================================

-- Unified annotation store: highlights, notes and bookmarks all live here,
-- distinguished by `type`. Anchors are stored structurally (book/para/line +
-- offsets) AND as a text quote (exact/prefix/suffix) so highlights can be
-- re-anchored across devices even if content shifts.
create table if not exists annotations (
  id            uuid primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  type          text not null check (type in ('highlight', 'note', 'bookmark')),
  book_id       text not null,
  book_name     text,
  para_id       integer,
  line_id       integer,
  segment       text,           -- 'pali' | 'translation' | null (bookmark)
  lang_code     text,           -- translation language, when segment='translation'
  start_offset  integer,        -- char offset in the stripped segment text
  end_offset    integer,
  exact_text    text,           -- selected text (quote selector)
  prefix_text   text,           -- ~30 chars before the selection
  suffix_text   text,           -- ~30 chars after the selection
  color         text,           -- highlight color key ('yellow', 'green', ...)
  note          text,           -- markdown note body
  name          text,           -- bookmark name
  page_number   text,           -- bookmark page number
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz     -- soft-delete marker for sync
);

-- Lookups by user (all rows) and by user+book (reader panel).
create index if not exists annotations_user_idx
  on annotations (user_id, updated_at desc);
create index if not exists annotations_book_idx
  on annotations (user_id, book_id, updated_at desc);

-- Row-level security: users can only see / touch their own rows.
alter table annotations enable row level security;

drop policy if exists "annotations_select_own" on annotations;
create policy "annotations_select_own"
  on annotations for select
  using (auth.uid() = user_id);

drop policy if exists "annotations_insert_own" on annotations;
create policy "annotations_insert_own"
  on annotations for insert
  with check (auth.uid() = user_id);

drop policy if exists "annotations_update_own" on annotations;
create policy "annotations_update_own"
  on annotations for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "annotations_delete_own" on annotations;
create policy "annotations_delete_own"
  on annotations for delete
  using (auth.uid() = user_id);

-- Push annotation changes to other signed-in devices in real time.
alter publication supabase_realtime add table annotations;

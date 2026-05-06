-- CLEANCITY Cameroun - Row Level Security policies

alter table public.users enable row level security;
alter table public.addresses enable row level security;
alter table public.waste_requests enable row level security;
alter table public.pickups enable row level security;
alter table public.processing_events enable row level security;
alter table public.eco_transactions enable row level security;
alter table public.waste_request_photos enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_thread_members enable row level security;
alter table public.chat_messages enable row level security;

-- USERS: allow everyone authenticated to insert/update their row during onboarding.
-- IMPORTANT per Dreamflow guideline: WITH CHECK (true) for INSERT and UPDATE.
create policy "users_select_own" on public.users
  for select
  to authenticated
  using (id = auth.uid());

create policy "users_insert_any" on public.users
  for insert
  to authenticated
  with check (true);

create policy "users_update_any" on public.users
  for update
  to authenticated
  using (id = auth.uid())
  with check (true);

create policy "users_delete_own" on public.users
  for delete
  to authenticated
  using (id = auth.uid());

-- All other tables: allow authenticated users to perform all operations.
create policy "addresses_all" on public.addresses
  for all
  to authenticated
  using (true)
  with check (true);

create policy "waste_requests_all" on public.waste_requests
  for all
  to authenticated
  using (true)
  with check (true);

create policy "pickups_all" on public.pickups
  for all
  to authenticated
  using (true)
  with check (true);

create policy "processing_events_all" on public.processing_events
  for all
  to authenticated
  using (true)
  with check (true);

create policy "eco_transactions_all" on public.eco_transactions
  for all
  to authenticated
  using (true)
  with check (true);

create policy "waste_request_photos_all" on public.waste_request_photos
  for all
  to authenticated
  using (true)
  with check (true);

-- --- CHAT ---
-- NOTE: for a first iteration we keep policies permissive (authenticated users)
-- but restricted to membership checks.

drop policy if exists "threads_select_members" on public.chat_threads;
create policy "threads_select_members" on public.chat_threads
  for select
  to authenticated
  using (
    exists(
      select 1 from public.chat_thread_members m
      where m.thread_id = chat_threads.id and m.user_id = auth.uid()
    )
  );

drop policy if exists "threads_insert_any" on public.chat_threads;
create policy "threads_insert_any" on public.chat_threads
  for insert
  to authenticated
  with check (true);

drop policy if exists "members_select_members" on public.chat_thread_members;
create policy "members_select_members" on public.chat_thread_members
  for select
  to authenticated
  using (
    exists(
      select 1 from public.chat_thread_members m
      where m.thread_id = chat_thread_members.thread_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "members_insert_any" on public.chat_thread_members;
create policy "members_insert_any" on public.chat_thread_members
  for insert
  to authenticated
  with check (true);

drop policy if exists "messages_select_members" on public.chat_messages;
create policy "messages_select_members" on public.chat_messages
  for select
  to authenticated
  using (
    exists(
      select 1 from public.chat_thread_members m
      where m.thread_id = chat_messages.thread_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "messages_insert_members" on public.chat_messages;
create policy "messages_insert_members" on public.chat_messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists(
      select 1 from public.chat_thread_members m
      where m.thread_id = chat_messages.thread_id and m.user_id = auth.uid()
    )
  );

-- Supabase Storage (buckets & policies)
-- You must create these buckets in Supabase Dashboard > Storage:
-- 1) user_uploads (public)
-- 2) request_photos (public)
-- Then add storage policies (Storage > Policies) or run SQL like:
--
-- create policy "public read" on storage.objects for select to public
--   using (bucket_id in ('user_uploads', 'request_photos'));
--
-- create policy "authenticated upload" on storage.objects for insert to authenticated
--   with check (bucket_id in ('user_uploads', 'request_photos'));

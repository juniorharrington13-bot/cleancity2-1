-- chat_messages: the bare `thread_id` in the subquery was resolving to the
-- subquery's own chat_thread_members.thread_id instead of the outer
-- chat_messages.thread_id, making the membership check a no-op (matched ANY
-- thread the user belongs to, not the message's own thread).
drop policy chat_messages_select_member on public.chat_messages;
create policy chat_messages_select_member on public.chat_messages
  for select to authenticated using (
    exists (select 1 from public.chat_thread_members m where m.thread_id = chat_messages.thread_id and m.user_id = auth.uid())
  );

drop policy chat_messages_insert_member on public.chat_messages;
create policy chat_messages_insert_member on public.chat_messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (select 1 from public.chat_thread_members m where m.thread_id = chat_messages.thread_id and m.user_id = auth.uid())
  );

-- waste_requests: same bug, `id` resolved to pickups.id instead of
-- waste_requests.id, so the collector-owns-this-mission check never matched.
drop policy waste_requests_update_owner_or_agent on public.waste_requests;
create policy waste_requests_update_owner_or_agent on public.waste_requests
  for update to authenticated using (
    generator_id = auth.uid()
    or exists (select 1 from public.pickups p where p.request_id = waste_requests.id and p.collector_id = auth.uid())
    or public.current_user_role() in ('center', 'admin')
  );

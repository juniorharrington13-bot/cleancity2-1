create or replace function public.is_thread_member(p_thread_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_thread_members m
    where m.thread_id = p_thread_id and m.user_id = auth.uid()
  );
$$;
revoke execute on function public.is_thread_member(uuid) from anon;

drop policy chat_thread_members_select_member on public.chat_thread_members;
create policy chat_thread_members_select_member on public.chat_thread_members
  for select to authenticated using (
    user_id = auth.uid() or public.is_thread_member(thread_id)
  );

drop policy chat_thread_members_insert_member on public.chat_thread_members;
create policy chat_thread_members_insert_member on public.chat_thread_members
  for insert to authenticated with check (
    user_id = auth.uid() or public.is_thread_member(thread_id)
  );

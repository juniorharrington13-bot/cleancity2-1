-- Fix mutable search_path on trigger helper.
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- handle_new_auth_user must only run via the auth.users trigger, never as a public RPC.
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

-- current_user_role / is_request_participant are only needed by RLS policies
-- evaluated as `authenticated`; anon has no use for them.
revoke execute on function public.current_user_role() from anon;
revoke execute on function public.is_request_participant(uuid) from anon;

-- Tighten chat_threads insert: no more "with check (true)". A request-thread
-- requires the caller to be a participant of that request; a direct-thread
-- requires the caller's id to be encoded in direct_key (format "a_b").
drop policy chat_threads_insert_authenticated on public.chat_threads;
create policy chat_threads_insert_participant on public.chat_threads
  for insert to authenticated with check (
    (kind = 'request' and public.is_request_participant(request_id))
    or (kind = 'direct' and (
      direct_key like (auth.uid()::text || '\_%')
      or direct_key like ('%\_' || auth.uid()::text)
    ))
  );

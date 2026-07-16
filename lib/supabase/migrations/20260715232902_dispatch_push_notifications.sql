-- ---------------------------------------------------------------------------
-- Forward every in-app notification to the send-push-notification Edge
-- Function so it also reaches the device's system tray via OneSignal, not
-- just the in-app bell/list. Fire-and-forget via pg_net (async HTTP from
-- Postgres) so notification writes never block on an external call.
-- ---------------------------------------------------------------------------

create extension if not exists pg_net;

create or replace function public.dispatch_push_notification()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://ixrebfrxhfapndprujvt.supabase.co/functions/v1/send-push-notification',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'user_id', new.user_id,
      'title', new.title,
      'body', new.body,
      'type', new.type,
      'related_id', new.related_id
    )
  );
  return new;
exception when others then
  -- Never let a push-delivery hiccup roll back the notification write itself.
  return new;
end;
$$;

create trigger dispatch_push_notification after insert on public.notifications
  for each row execute function public.dispatch_push_notification();

-- ---------------------------------------------------------------------------
-- Disputes: lets any participant of a request (generator, collector, center)
-- flag a problem (e.g. collector no-show, weight mismatch, payment issue) for
-- an admin to review and resolve. Purely additive — never blocks the
-- underlying request/pickup/payout flow.
-- ---------------------------------------------------------------------------

create type public.dispute_status as enum ('open', 'in_review', 'resolved', 'dismissed');

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.waste_requests (id) on delete cascade,
  reported_by uuid not null references public.users (id) on delete cascade,
  against_user_id uuid references public.users (id) on delete set null,
  category text not null,
  description text not null check (char_length(trim(description)) > 0),
  status public.dispute_status not null default 'open',
  admin_note text,
  resolved_by uuid references public.users (id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index disputes_request_idx on public.disputes (request_id);
create index disputes_reported_by_idx on public.disputes (reported_by);
create index disputes_status_idx on public.disputes (status);

create trigger set_updated_at before update on public.disputes
  for each row execute function public.set_updated_at();

alter table public.disputes enable row level security;

-- A participant can see disputes they filed, disputes filed against them, or
-- any dispute tied to a request they're part of; admins see everything.
create policy disputes_select_participant on public.disputes
  for select to authenticated using (
    reported_by = auth.uid()
    or against_user_id = auth.uid()
    or public.is_request_participant(request_id)
    or public.current_user_role() = 'admin'
  );

create policy disputes_insert_participant on public.disputes
  for insert to authenticated with check (
    reported_by = auth.uid() and public.is_request_participant(request_id)
  );

-- Only an admin resolves/dismisses a dispute (sets status/admin_note).
create policy disputes_update_admin on public.disputes
  for update to authenticated using (public.current_user_role() = 'admin');

-- ---------------------------------------------------------------------------
-- Trigger: a dispute is filed -> notify every admin.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_dispute()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_admin record;
  v_reporter_name text;
begin
  select coalesce(full_name, 'Un utilisateur') into v_reporter_name from public.users where id = new.reported_by;
  for v_admin in select id from public.users where role = 'admin' loop
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      v_admin.id,
      'dispute_opened',
      'Nouveau litige signalé',
      v_reporter_name || ' a signalé un problème (' || new.category || ').',
      new.id
    );
  end loop;
  return new;
end;
$$;

create trigger notify_new_dispute after insert on public.disputes
  for each row execute function public.notify_new_dispute();

-- ---------------------------------------------------------------------------
-- Trigger: an admin resolves/dismisses a dispute -> notify the reporter.
-- ---------------------------------------------------------------------------
create or replace function public.notify_dispute_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and new.status in ('resolved', 'dismissed') then
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      new.reported_by,
      'dispute_' || new.status,
      case when new.status = 'resolved' then 'Litige résolu' else 'Litige clos' end,
      coalesce(new.admin_note, case when new.status = 'resolved'
        then 'Votre signalement a été traité.'
        else 'Votre signalement a été clos sans suite.'
      end),
      new.id
    );
  end if;
  return new;
end;
$$;

create trigger notify_dispute_status_change after update on public.disputes
  for each row execute function public.notify_dispute_status_change();

-- ---------------------------------------------------------------------------
-- In-app notifications: a single table drives a bell icon + unread badge on
-- every dashboard. Rows are only ever written by SECURITY DEFINER trigger
-- functions (or the confirm_reception_and_payout RPC) — no INSERT policy is
-- granted to clients, so a user can never fabricate a notification for
-- themselves or anyone else.
-- ---------------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  related_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = auth.uid());
-- Update is scoped to the owner's own rows (used to mark read); a user can
-- only ever affect their own view, never another user's data, so allowing a
-- full-row update here (rather than a column-restricted one) is harmless.
create policy notifications_update_own on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Trigger: a center requests a wallet top-up -> notify every admin.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_topup_request()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_admin record;
  v_center_name text;
begin
  select coalesce(full_name, 'Un centre') into v_center_name from public.users where id = new.center_id;
  for v_admin in select id from public.users where role = 'admin' loop
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      v_admin.id,
      'wallet_topup_requested',
      'Nouvelle demande de recharge',
      v_center_name || ' a demandé une recharge de ' || new.amount_xaf || ' XAF.',
      new.id
    );
  end loop;
  return new;
end;
$$;

create trigger notify_new_topup_request after insert on public.wallet_topups
  for each row execute function public.notify_new_topup_request();

-- ---------------------------------------------------------------------------
-- Trigger: an admin confirms/rejects a top-up -> notify the center.
-- ---------------------------------------------------------------------------
create or replace function public.notify_topup_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and new.status <> 'pending' then
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      new.center_id,
      'wallet_topup_' || new.status,
      case when new.status = 'confirmed' then 'Recharge confirmée' else 'Recharge rejetée' end,
      case when new.status = 'confirmed'
        then 'Votre recharge de ' || new.amount_xaf || ' XAF a été confirmée et ajoutée à votre solde.'
        else 'Votre demande de recharge de ' || new.amount_xaf || ' XAF a été rejetée.'
      end,
      new.id
    );
  end if;
  return new;
end;
$$;

create trigger notify_topup_status_change after update on public.wallet_topups
  for each row execute function public.notify_topup_status_change();

-- ---------------------------------------------------------------------------
-- Trigger: a mobile-money withdrawal request changes status -> notify the user.
-- ---------------------------------------------------------------------------
create or replace function public.notify_payout_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and new.status <> 'pending' then
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      new.user_id,
      'payout_request_' || new.status,
      case new.status
        when 'paid' then 'Retrait effectué'
        when 'approved' then 'Retrait approuvé'
        else 'Retrait rejeté'
      end,
      case new.status
        when 'paid' then 'Votre retrait de ' || new.amount_xaf || ' XAF via ' || new.provider || ' a été payé.'
        when 'approved' then 'Votre retrait de ' || new.amount_xaf || ' XAF a été approuvé.'
        else 'Votre demande de retrait de ' || new.amount_xaf || ' XAF a été rejetée.'
      end,
      new.id
    );
  end if;
  return new;
end;
$$;

create trigger notify_payout_status_change after update on public.payout_requests
  for each row execute function public.notify_payout_status_change();

-- ---------------------------------------------------------------------------
-- Trigger: a waste request's status changes -> notify the generator.
-- ---------------------------------------------------------------------------
create or replace function public.notify_request_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_label text;
begin
  if new.status is distinct from old.status then
    v_label := case new.status
      when 'accepted' then 'acceptée par un collecteur'
      when 'collected' then 'collectée'
      when 'delivered' then 'livrée au centre de tri'
      when 'cancelled' then 'annulée'
      else new.status::text
    end;
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      new.generator_id,
      'request_' || new.status,
      'Mise à jour de votre demande',
      'Votre demande de collecte a été ' || v_label || '.',
      new.id
    );
  end if;
  return new;
end;
$$;

create trigger notify_request_status_change after update on public.waste_requests
  for each row execute function public.notify_request_status_change();

-- ---------------------------------------------------------------------------
-- Trigger: a chat message is sent -> notify the other thread members.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_chat_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_sender_name text;
  v_member record;
  v_preview text;
begin
  select coalesce(full_name, 'Quelqu''un') into v_sender_name from public.users where id = new.sender_id;
  v_preview := left(new.body, 80);
  for v_member in
    select user_id from public.chat_thread_members where thread_id = new.thread_id and user_id <> new.sender_id
  loop
    insert into public.notifications (user_id, type, title, body, related_id)
    values (v_member.user_id, 'chat_message', v_sender_name, v_preview, new.thread_id);
  end loop;
  return new;
end;
$$;

create trigger notify_new_chat_message after insert on public.chat_messages
  for each row execute function public.notify_new_chat_message();

-- ---------------------------------------------------------------------------
-- Re-define confirm_reception_and_payout to also notify the collector when
-- they're paid (full body restated — Postgres requires it on replace).
-- ---------------------------------------------------------------------------
create or replace function public.confirm_reception_and_payout(
  p_request_id uuid,
  p_weighed_kg numeric,
  p_accepted boolean default true,
  p_notes text default null
)
returns numeric
language plpgsql security definer set search_path = public as $$
declare
  v_center_id uuid := auth.uid();
  v_owns boolean;
  v_collector_id uuid;
  v_already boolean;
  v_waste_type text;
  v_rates jsonb;
  v_rate numeric;
  v_amount numeric;
  v_balance numeric;
begin
  if public.current_user_role() is distinct from 'center' and public.current_user_role() is distinct from 'admin' then
    raise exception 'FORBIDDEN: only a center can confirm reception';
  end if;

  select exists (
    select 1 from public.pickups p where p.request_id = p_request_id and p.center_id = v_center_id
  ) or exists (
    select 1 from public.waste_requests wr where wr.id = p_request_id and wr.center_id = v_center_id
  ) into v_owns;
  if not v_owns then
    raise exception 'NOT_YOUR_DELIVERY';
  end if;

  insert into public.processing_events (request_id, center_id, weighed_kg, accepted, notes)
    values (p_request_id, v_center_id, p_weighed_kg, p_accepted, p_notes);

  if not p_accepted then
    return 0;
  end if;

  select collector_id into v_collector_id from public.pickups where request_id = p_request_id limit 1;
  if v_collector_id is null then
    return 0;
  end if;

  select exists (
    select 1 from public.eco_transactions
    where user_id = v_collector_id and request_id = p_request_id and reason = 'payout'
  ) into v_already;
  if v_already then
    return 0;
  end if;

  select waste_type::text into v_waste_type from public.waste_requests where id = p_request_id;
  v_waste_type := coalesce(v_waste_type, 'mixed');

  select value into v_rates from public.app_settings where key = 'waste_rates_xaf_per_kg';
  v_rate := coalesce(
    (v_rates ->> v_waste_type)::numeric,
    (v_rates ->> 'mixed')::numeric,
    case v_waste_type
      when 'plastic' then 150
      when 'paper' then 90
      when 'glass' then 60
      when 'organic' then 50
      when 'metal' then 200
      when 'ewaste' then 300
      else 75
    end
  );

  v_amount := round(p_weighed_kg * v_rate);

  select coalesce(sum(amount_xaf), 0) into v_balance
    from public.center_wallet_transactions where center_id = v_center_id;
  if v_balance < v_amount then
    raise exception 'INSUFFICIENT_BALANCE';
  end if;

  insert into public.center_wallet_transactions (center_id, type, amount_xaf, request_id)
    values (v_center_id, 'payout_debit', -v_amount, p_request_id);

  insert into public.eco_transactions (user_id, request_id, points, reason, updated_at)
    values (v_collector_id, p_request_id, v_amount, 'payout', now());

  insert into public.notifications (user_id, type, title, body, related_id)
    values (v_collector_id, 'wallet_payout_received', 'Paiement reçu',
      'Vous avez été payé ' || v_amount || ' XAF pour une livraison.', p_request_id);

  return v_amount;
end;
$$;

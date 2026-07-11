-- ---------------------------------------------------------------------------
-- Center wallet: centres top up a balance ("monnaie électronique") that funds
-- collector payouts on delivery reception. Payout amounts are computed
-- server-side (not trusted from the client) and capped by the center's
-- wallet balance, atomically, via confirm_reception_and_payout().
-- ---------------------------------------------------------------------------

create type public.wallet_topup_status as enum ('pending', 'confirmed', 'rejected');
create type public.wallet_transaction_type as enum ('topup', 'payout_debit', 'adjustment');

create table public.wallet_topups (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.users (id) on delete cascade,
  amount_xaf integer not null check (amount_xaf > 0),
  provider text not null,
  phone text not null,
  reference text,
  status public.wallet_topup_status not null default 'pending',
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index wallet_topups_center_idx on public.wallet_topups (center_id);

create table public.center_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.users (id) on delete cascade,
  type public.wallet_transaction_type not null,
  amount_xaf numeric not null, -- signed: positive = credit, negative = debit
  topup_id uuid references public.wallet_topups (id) on delete set null,
  request_id uuid references public.waste_requests (id) on delete set null,
  created_at timestamptz not null default now()
);
create index center_wallet_tx_center_idx on public.center_wallet_transactions (center_id);

create trigger set_updated_at before update on public.wallet_topups
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.wallet_topups enable row level security;
alter table public.center_wallet_transactions enable row level security;

-- wallet_topups: the center manages its own top-up requests; only an admin
-- can confirm/reject (via confirm_wallet_topup below, which uses this policy
-- indirectly since it is SECURITY DEFINER and updates the row itself, but we
-- still expose an update policy for direct admin edits e.g. notes).
create policy wallet_topups_select_own on public.wallet_topups
  for select to authenticated using (center_id = auth.uid() or public.current_user_role() = 'admin');
create policy wallet_topups_insert_self on public.wallet_topups
  for insert to authenticated with check (
    center_id = auth.uid() and public.current_user_role() in ('center', 'admin')
  );
create policy wallet_topups_update_admin on public.wallet_topups
  for update to authenticated using (public.current_user_role() = 'admin');

-- center_wallet_transactions: read-only for the owning center/admin. No insert
-- or update policy at all — rows are only ever written by the SECURITY
-- DEFINER functions below (confirm_wallet_topup, confirm_reception_and_payout),
-- which bypass RLS. This prevents any client, including the center itself,
-- from fabricating a wallet credit.
create policy center_wallet_tx_select_own on public.center_wallet_transactions
  for select to authenticated using (center_id = auth.uid() or public.current_user_role() = 'admin');

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Admin confirms or rejects a pending top-up. On confirm, credits the
-- center's wallet with a `topup` transaction.
create or replace function public.confirm_wallet_topup(
  p_topup_id uuid,
  p_approve boolean,
  p_admin_note text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_topup public.wallet_topups;
begin
  -- `<>` propagates NULL (i.e. skips the raise) for an unauthenticated
  -- caller, since current_user_role() is NULL when auth.uid() is NULL —
  -- IS DISTINCT FROM treats NULL as a real, non-admin value instead.
  if public.current_user_role() is distinct from 'admin' then
    raise exception 'FORBIDDEN: only an admin can confirm top-ups';
  end if;

  select * into v_topup from public.wallet_topups where id = p_topup_id for update;
  if v_topup.id is null then
    raise exception 'TOPUP_NOT_FOUND';
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'ALREADY_PROCESSED';
  end if;

  if p_approve then
    update public.wallet_topups
      set status = 'confirmed', admin_note = p_admin_note, updated_at = now()
      where id = p_topup_id;

    insert into public.center_wallet_transactions (center_id, type, amount_xaf, topup_id)
      values (v_topup.center_id, 'topup', v_topup.amount_xaf, p_topup_id);
  else
    update public.wallet_topups
      set status = 'rejected', admin_note = p_admin_note, updated_at = now()
      where id = p_topup_id;
  end if;
end;
$$;

-- Center confirms a delivery reception: records the weigh-in, then — if
-- accepted — computes the payout server-side, checks the center's wallet
-- balance can cover it, and atomically debits the center wallet while
-- crediting the collector's eco_transactions ledger. Returns the amount paid
-- (0 if not accepted, no collector found, or already paid).
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
  -- Same NULL-propagation hazard as confirm_wallet_topup: NOT IN skips the
  -- raise for an unauthenticated caller since current_user_role() is NULL.
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

  return v_amount;
end;
$$;

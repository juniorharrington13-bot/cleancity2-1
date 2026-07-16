-- ---------------------------------------------------------------------------
-- Generator eco-points: a generator earns a fixed number of points each time
-- one of their requests is accepted/weighed at a center (same moment the
-- collector gets paid). Points accumulate in eco_transactions (reason
-- 'generator_participation'); once a configurable threshold is crossed, the
-- generator is notified they can request a Mobile Money withdrawal via the
-- existing payout_requests flow (role-agnostic, already used by collectors).
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value)
values
  ('generator_points_per_request', '10'::jsonb),
  ('generator_points_payout', '{"threshold_points": 100, "amount_xaf": 2000}'::jsonb)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Non-blocking generator pickup confirmation: purely informational, doesn't
-- gate the collector's own markCollected flow.
-- ---------------------------------------------------------------------------
alter table public.pickups add column if not exists generator_confirmed_at timestamptz;

create or replace function public.confirm_pickup_as_generator(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_owns boolean;
begin
  select exists (
    select 1 from public.waste_requests wr
    where wr.id = p_request_id and wr.generator_id = auth.uid()
  ) into v_owns;
  if not v_owns then
    raise exception 'NOT_YOUR_REQUEST';
  end if;

  update public.pickups
    set generator_confirmed_at = now()
    where request_id = p_request_id and generator_confirmed_at is null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Notify the generator once they cross a new points threshold.
-- ---------------------------------------------------------------------------
create or replace function public.notify_generator_points_threshold()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_threshold numeric;
  v_new_total numeric;
  v_old_total numeric;
begin
  if new.reason is distinct from 'generator_participation' then
    return new;
  end if;

  select coalesce((value ->> 'threshold_points')::numeric, 100)
    into v_threshold
    from public.app_settings where key = 'generator_points_payout';
  v_threshold := coalesce(v_threshold, 100);

  select coalesce(sum(points), 0) into v_new_total
    from public.eco_transactions
    where user_id = new.user_id and reason = 'generator_participation';
  v_old_total := v_new_total - new.points;

  if v_threshold > 0 and floor(v_new_total / v_threshold) > floor(v_old_total / v_threshold) then
    insert into public.notifications (user_id, type, title, body, related_id)
    values (
      new.user_id,
      'generator_points_threshold',
      'Seuil de points éco atteint !',
      'Vous avez accumulé assez de points éco pour demander un retrait depuis votre tableau de bord.',
      new.request_id
    );
  end if;

  return new;
end;
$$;

create trigger notify_generator_points_threshold after insert on public.eco_transactions
  for each row execute function public.notify_generator_points_threshold();

-- ---------------------------------------------------------------------------
-- Re-define confirm_reception_and_payout to also credit the generator's
-- eco-points (fixed amount per completed request) alongside the collector's
-- XAF payout (full body restated — Postgres requires it on replace).
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
  v_generator_id uuid;
  v_already boolean;
  v_waste_type text;
  v_rates jsonb;
  v_rate numeric;
  v_amount numeric;
  v_balance numeric;
  v_generator_points numeric;
  v_generator_already boolean;
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

  -- Generator eco-points: fixed amount per completed request, credited once.
  select generator_id into v_generator_id from public.waste_requests where id = p_request_id;
  if v_generator_id is not null then
    select exists (
      select 1 from public.eco_transactions
      where user_id = v_generator_id and request_id = p_request_id and reason = 'generator_participation'
    ) into v_generator_already;
    if not v_generator_already then
      select coalesce((value #>> '{}')::numeric, 10) into v_generator_points
        from public.app_settings where key = 'generator_points_per_request';
      v_generator_points := coalesce(v_generator_points, 10);
      insert into public.eco_transactions (user_id, request_id, points, reason, updated_at)
        values (v_generator_id, p_request_id, v_generator_points, 'generator_participation', now());
    end if;
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

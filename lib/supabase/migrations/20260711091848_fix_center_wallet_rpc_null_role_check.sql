-- Fixes a NULL-propagation hazard: `<>` / `NOT IN` against
-- current_user_role() evaluate to NULL (not TRUE) for an unauthenticated
-- caller (auth.uid() is NULL), and `IF NULL THEN` is silently skipped in
-- PL/pgSQL — so the FORBIDDEN guard never fired for anonymous callers.
-- IS DISTINCT FROM treats NULL as a real, non-matching value, closing the gap.

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

  return v_amount;
end;
$$;

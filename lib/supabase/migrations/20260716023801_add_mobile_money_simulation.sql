-- ---------------------------------------------------------------------------
-- Simulated Mobile Money gateway: getting real MTN/Orange Money merchant API
-- credentials involves a lengthy administrative process, so withdrawals and
-- wallet top-ups are completed via a client-side simulated gateway (fake
-- processing delay + generated transaction reference) instead of a real
-- payment API call. These RPCs let the owning user self-resolve their own
-- pending request with the simulated outcome — an admin can still intervene
-- manually via the existing confirm_wallet_topup RPC / admin payout actions
-- if needed.
-- ---------------------------------------------------------------------------

alter table public.payout_requests add column if not exists reference text;
alter table public.payout_requests add column if not exists admin_note text;

create or replace function public.simulate_mobile_money_payout(
  p_payout_id uuid,
  p_success boolean,
  p_reference text,
  p_failure_reason text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_status public.payout_status;
begin
  select user_id, status into v_owner, v_status from public.payout_requests where id = p_payout_id;
  if v_owner is null then
    raise exception 'PAYOUT_NOT_FOUND';
  end if;
  if v_owner is distinct from auth.uid() then
    raise exception 'FORBIDDEN: not your payout request';
  end if;
  if v_status is distinct from 'pending' then
    raise exception 'ALREADY_PROCESSED';
  end if;

  update public.payout_requests
    set status = case when p_success then 'paid' else 'rejected' end,
        reference = p_reference,
        admin_note = case when p_success then null else p_failure_reason end,
        updated_at = now()
    where id = p_payout_id;
end;
$$;

create or replace function public.simulate_mobile_money_topup(
  p_topup_id uuid,
  p_success boolean,
  p_reference text,
  p_failure_reason text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_center_id uuid;
  v_amount int;
  v_status public.wallet_topup_status;
begin
  select center_id, amount_xaf, status into v_center_id, v_amount, v_status
    from public.wallet_topups where id = p_topup_id;
  if v_center_id is null then
    raise exception 'TOPUP_NOT_FOUND';
  end if;
  if v_center_id is distinct from auth.uid() then
    raise exception 'FORBIDDEN: not your top-up request';
  end if;
  if v_status is distinct from 'pending' then
    raise exception 'ALREADY_PROCESSED';
  end if;

  if p_success then
    update public.wallet_topups
      set status = 'confirmed', reference = p_reference, updated_at = now()
      where id = p_topup_id;
    insert into public.center_wallet_transactions (center_id, type, amount_xaf, topup_id)
      values (v_center_id, 'topup', v_amount, p_topup_id);
  else
    update public.wallet_topups
      set status = 'rejected', reference = p_reference, admin_note = p_failure_reason, updated_at = now()
      where id = p_topup_id;
  end if;
end;
$$;

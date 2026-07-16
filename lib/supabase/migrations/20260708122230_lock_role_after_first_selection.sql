alter table public.users add column role_confirmed_at timestamptz;

update public.users set role_confirmed_at = created_at where role_confirmed_at is null;

create or replace function public.enforce_role_change()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    if public.current_user_role() = 'admin' then
      if new.role_confirmed_at is null then
        new.role_confirmed_at = now();
      end if;
    elsif old.role_confirmed_at is null then
      new.role_confirmed_at = now();
    else
      raise exception 'ROLE_ALREADY_CONFIRMED: seul un administrateur peut modifier ce role.';
    end if;
  end if;
  return new;
end;
$$;

create trigger enforce_role_change before update on public.users
  for each row execute function public.enforce_role_change();

-- Bootstrap the first admin account (bypass the trigger for this one-time seed).
alter table public.users disable trigger enforce_role_change;
update public.users set role = 'admin', role_confirmed_at = now()
where email = 'juniorcurry8888@gmail.com';
alter table public.users enable trigger enforce_role_change;

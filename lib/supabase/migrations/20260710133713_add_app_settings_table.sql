create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id)
);

alter table public.app_settings enable row level security;

create policy app_settings_select_authenticated on public.app_settings
  for select to authenticated using (true);
create policy app_settings_upsert_admin on public.app_settings
  for insert to authenticated with check (public.current_user_role() = 'admin');
create policy app_settings_update_admin on public.app_settings
  for update to authenticated using (public.current_user_role() = 'admin');

insert into public.app_settings (key, value) values
  ('waste_rates_xaf_per_kg', '{"mixed":75,"plastic":150,"paper":90,"glass":60,"organic":50,"metal":200,"ewaste":300}'::jsonb),
  ('recovery_rate_goal_percent', '70'::jsonb)
on conflict (key) do nothing;

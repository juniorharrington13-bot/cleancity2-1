-- ============================================================================
-- CLEAN CITY — Schema complet (extensions, tables, RLS, storage, auth)
-- ============================================================================

create extension if not exists postgis with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. ENUMS
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('generator', 'collector', 'center', 'admin');
create type public.waste_type as enum ('mixed', 'plastic', 'paper', 'glass', 'organic', 'metal', 'ewaste');
create type public.waste_status as enum ('pending', 'accepted', 'collected', 'delivered', 'cancelled');
create type public.payout_status as enum ('pending', 'approved', 'paid', 'rejected');
create type public.thread_kind as enum ('request', 'direct');

-- ---------------------------------------------------------------------------
-- 2. TABLES
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  role public.user_role not null default 'generator',
  full_name text,
  phone_e164 text not null default '',
  preferred_language text not null default 'fr',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  label text,
  city text,
  neighborhood text,
  details text,
  latitude double precision,
  longitude double precision,
  location geography(Point, 4326)
    generated always as (
      case when latitude is not null and longitude is not null
        then st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
        else null
      end
    ) stored,
  created_at timestamptz not null default now()
);

create table public.waste_requests (
  id uuid primary key default gen_random_uuid(),
  generator_id uuid not null references public.users (id) on delete cascade,
  address_id uuid references public.addresses (id) on delete set null,
  center_id uuid references public.users (id) on delete set null,
  waste_type public.waste_type not null default 'mixed',
  quantity_estimate_kg numeric not null check (quantity_estimate_kg >= 0),
  notes text,
  status public.waste_status not null default 'pending',
  scheduled_at timestamptz,
  time_slot text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pickups (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.waste_requests (id) on delete cascade,
  collector_id uuid not null references public.users (id) on delete cascade,
  center_id uuid references public.users (id) on delete set null,
  accepted_at timestamptz not null default now(),
  collected_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.waste_request_photos (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.waste_requests (id) on delete cascade,
  uploaded_by uuid not null references public.users (id) on delete cascade,
  url text not null,
  created_at timestamptz not null default now()
);

create table public.processing_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.waste_requests (id) on delete cascade,
  center_id uuid not null references public.users (id) on delete cascade,
  weighed_kg numeric not null check (weighed_kg >= 0),
  accepted boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table public.eco_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  request_id uuid references public.waste_requests (id) on delete set null,
  points numeric not null,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, request_id, reason)
);

create table public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  provider text not null,
  phone text not null,
  amount_xaf integer not null check (amount_xaf > 0),
  status public.payout_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  kind public.thread_kind not null default 'request',
  request_id uuid references public.waste_requests (id) on delete cascade,
  direct_key text,
  created_at timestamptz not null default now(),
  constraint chat_threads_kind_check check (
    (kind = 'request' and request_id is not null and direct_key is null) or
    (kind = 'direct' and direct_key is not null and request_id is null)
  )
);
create unique index chat_threads_request_id_key on public.chat_threads (request_id) where request_id is not null;
create unique index chat_threads_direct_key_key on public.chat_threads (direct_key) where direct_key is not null;

create table public.chat_thread_members (
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS (SECURITY DEFINER pour eviter la recursion RLS)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid();
$$;

create or replace function public.is_request_participant(p_request_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.waste_requests wr
    where wr.id = p_request_id
      and (wr.generator_id = auth.uid() or wr.center_id = auth.uid())
  ) or exists (
    select 1 from public.pickups p
    where p.request_id = p_request_id
      and (p.collector_id = auth.uid() or p.center_id = auth.uid())
  ) or public.current_user_role() = 'admin';
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email, full_name, phone_e164, preferred_language, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.phone, ''),
    'fr',
    'generator'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.nearby_waste_requests(
  lat double precision,
  lng double precision,
  radius_meters integer default 5000
)
returns setof public.waste_requests
language sql stable security definer set search_path = public, extensions as $$
  select wr.*
  from public.waste_requests wr
  join public.addresses a on a.id = wr.address_id
  where wr.status = 'pending'
    and a.location is not null
    and st_dwithin(a.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_meters)
  order by a.location <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography;
$$;

-- ---------------------------------------------------------------------------
-- 4. INDEXES
-- ---------------------------------------------------------------------------
create index addresses_location_gix on public.addresses using gist (location);
create index addresses_user_id_idx on public.addresses (user_id);

create index waste_requests_generator_idx on public.waste_requests (generator_id);
create index waste_requests_center_idx on public.waste_requests (center_id);
create index waste_requests_status_idx on public.waste_requests (status);

create index pickups_collector_idx on public.pickups (collector_id);
create index pickups_center_idx on public.pickups (center_id);

create index waste_request_photos_request_idx on public.waste_request_photos (request_id);
create index processing_events_request_idx on public.processing_events (request_id);
create index eco_transactions_user_idx on public.eco_transactions (user_id);
create index payout_requests_user_idx on public.payout_requests (user_id);
create index chat_thread_members_user_idx on public.chat_thread_members (user_id);
create index chat_messages_thread_idx on public.chat_messages (thread_id, created_at);

-- ---------------------------------------------------------------------------
-- 5. TRIGGERS
-- ---------------------------------------------------------------------------
create trigger set_updated_at before update on public.users
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.waste_requests
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.pickups
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.eco_transactions
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.payout_requests
  for each row execute function public.set_updated_at();

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.addresses enable row level security;
alter table public.waste_requests enable row level security;
alter table public.pickups enable row level security;
alter table public.waste_request_photos enable row level security;
alter table public.processing_events enable row level security;
alter table public.eco_transactions enable row level security;
alter table public.payout_requests enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_thread_members enable row level security;
alter table public.chat_messages enable row level security;

create policy users_select_authenticated on public.users
  for select to authenticated using (true);
create policy users_insert_self on public.users
  for insert to authenticated with check (id = auth.uid());
create policy users_update_self_or_admin on public.users
  for update to authenticated using (id = auth.uid() or public.current_user_role() = 'admin');

create policy addresses_select_authenticated on public.addresses
  for select to authenticated using (true);
create policy addresses_insert_self on public.addresses
  for insert to authenticated with check (user_id = auth.uid());
create policy addresses_update_self on public.addresses
  for update to authenticated using (user_id = auth.uid());

create policy waste_requests_select_authenticated on public.waste_requests
  for select to authenticated using (true);
create policy waste_requests_insert_self on public.waste_requests
  for insert to authenticated with check (generator_id = auth.uid());
create policy waste_requests_update_owner_or_agent on public.waste_requests
  for update to authenticated using (
    generator_id = auth.uid()
    or exists (select 1 from public.pickups p where p.request_id = id and p.collector_id = auth.uid())
    or public.current_user_role() in ('center', 'admin')
  );

create policy pickups_select_participant on public.pickups
  for select to authenticated using (
    collector_id = auth.uid()
    or center_id = auth.uid()
    or public.current_user_role() = 'admin'
    or exists (select 1 from public.waste_requests wr where wr.id = request_id and wr.generator_id = auth.uid())
  );
create policy pickups_insert_self on public.pickups
  for insert to authenticated with check (collector_id = auth.uid());
create policy pickups_update_participant on public.pickups
  for update to authenticated using (
    collector_id = auth.uid() or public.current_user_role() in ('center', 'admin')
  );

create policy photos_select_participant on public.waste_request_photos
  for select to authenticated using (public.is_request_participant(request_id));
create policy photos_insert_participant on public.waste_request_photos
  for insert to authenticated with check (uploaded_by = auth.uid() and public.is_request_participant(request_id));

create policy processing_events_select_participant on public.processing_events
  for select to authenticated using (public.is_request_participant(request_id));
create policy processing_events_insert_center on public.processing_events
  for insert to authenticated with check (
    center_id = auth.uid() and public.current_user_role() in ('center', 'admin')
  );

create policy eco_transactions_select_own on public.eco_transactions
  for select to authenticated using (user_id = auth.uid() or public.current_user_role() = 'admin');
create policy eco_transactions_insert_agent on public.eco_transactions
  for insert to authenticated with check (public.current_user_role() in ('center', 'admin'));

create policy payout_requests_select_own on public.payout_requests
  for select to authenticated using (user_id = auth.uid() or public.current_user_role() = 'admin');
create policy payout_requests_insert_self on public.payout_requests
  for insert to authenticated with check (user_id = auth.uid());
create policy payout_requests_update_admin on public.payout_requests
  for update to authenticated using (public.current_user_role() = 'admin');

create policy chat_threads_select_member on public.chat_threads
  for select to authenticated using (
    exists (select 1 from public.chat_thread_members m where m.thread_id = id and m.user_id = auth.uid())
  );
create policy chat_threads_insert_authenticated on public.chat_threads
  for insert to authenticated with check (true);

create policy chat_thread_members_select_member on public.chat_thread_members
  for select to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from public.chat_thread_members m where m.thread_id = thread_id and m.user_id = auth.uid())
  );
create policy chat_thread_members_insert_member on public.chat_thread_members
  for insert to authenticated with check (
    user_id = auth.uid()
    or exists (select 1 from public.chat_thread_members m where m.thread_id = thread_id and m.user_id = auth.uid())
  );

create policy chat_messages_select_member on public.chat_messages
  for select to authenticated using (
    exists (select 1 from public.chat_thread_members m where m.thread_id = thread_id and m.user_id = auth.uid())
  );
create policy chat_messages_insert_member on public.chat_messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (select 1 from public.chat_thread_members m where m.thread_id = thread_id and m.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 7. STORAGE (buckets + policies)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('user_uploads', 'user_uploads', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('request_photos', 'request_photos', false)
on conflict (id) do nothing;

create policy storage_user_uploads_public_read on storage.objects
  for select using (bucket_id = 'user_uploads');
create policy storage_user_uploads_own_write on storage.objects
  for insert to authenticated with check (
    bucket_id = 'user_uploads' and (storage.foldername(name))[2] = auth.uid()::text
  );
create policy storage_user_uploads_own_update on storage.objects
  for update to authenticated using (
    bucket_id = 'user_uploads' and (storage.foldername(name))[2] = auth.uid()::text
  );

create policy storage_request_photos_participant_read on storage.objects
  for select to authenticated using (
    bucket_id = 'request_photos'
    and public.is_request_participant(((storage.foldername(name))[2])::uuid)
  );
create policy storage_request_photos_participant_write on storage.objects
  for insert to authenticated with check (
    bucket_id = 'request_photos'
    and (storage.foldername(name))[3] = auth.uid()::text
    and public.is_request_participant(((storage.foldername(name))[2])::uuid)
  );

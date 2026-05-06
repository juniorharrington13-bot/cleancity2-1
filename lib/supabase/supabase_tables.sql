-- CLEANCITY Cameroun - Initial Supabase schema
-- Currency: XAF (handled at app layer); phone format: E.164 (+237...)

create extension if not exists "uuid-ossp";
-- Needed for gen_random_uuid() used in sample data and common Supabase patterns
create extension if not exists "pgcrypto";

-- Users profile table (public) linked to Supabase Auth (auth.users)
create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  avatar_url text,
  phone_e164 text not null default '',
  role text not null default 'generator' check (role in ('generator', 'collector', 'center', 'admin')),
  preferred_language text not null default 'fr' check (preferred_language in ('fr', 'en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.addresses (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users (id) on delete cascade,
  label text not null default 'Home',
  city text not null default '',
  neighborhood text not null default '',
  details text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A generator creates a pickup request; collectors can accept and fulfill.
create table if not exists public.waste_requests (
  id uuid primary key default uuid_generate_v4(),
  generator_id uuid not null references public.users (id) on delete restrict,
  address_id uuid references public.addresses (id) on delete set null,
  waste_type text not null default 'mixed' check (waste_type in ('mixed', 'plastic', 'paper', 'glass', 'organic', 'metal', 'ewaste')),
  quantity_estimate_kg numeric(10,2) not null default 0,
  notes text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'en_route', 'collected', 'delivered', 'cancelled')),
  scheduled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pickups (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null unique references public.waste_requests (id) on delete cascade,
  collector_id uuid not null references public.users (id) on delete restrict,
  accepted_at timestamptz not null default now(),
  collected_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Processing center records what it received (ties to request)
create table if not exists public.processing_events (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null references public.waste_requests (id) on delete cascade,
  center_id uuid not null references public.users (id) on delete restrict,
  received_at timestamptz not null default now(),
  weighed_kg numeric(10,2) not null default 0,
  accepted boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Eco-points / incentives ledger (can later back a wallet)
create table if not exists public.eco_transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users (id) on delete cascade,
  request_id uuid references public.waste_requests (id) on delete set null,
  points integer not null,
  reason text not null default 'pickup',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Photos attached to waste requests (stored in Supabase Storage)
create table if not exists public.waste_request_photos (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null references public.waste_requests (id) on delete cascade,
  uploaded_by uuid not null references public.users (id) on delete restrict,
  url text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_addresses_user_id on public.addresses (user_id);
create index if not exists idx_waste_requests_generator_id on public.waste_requests (generator_id);
create index if not exists idx_waste_requests_status on public.waste_requests (status);
create index if not exists idx_pickups_collector_id on public.pickups (collector_id);
create index if not exists idx_processing_events_center_id on public.processing_events (center_id);
create index if not exists idx_eco_transactions_user_id on public.eco_transactions (user_id);
create index if not exists idx_waste_request_photos_request_id on public.waste_request_photos (request_id);

-- --- CHAT ---
-- Basic request-centric chat (generator/collector/center) using Supabase Realtime.
create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  request_id uuid unique references public.waste_requests (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_thread_members (
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_thread_members_user_id on public.chat_thread_members (user_id);
create index if not exists idx_chat_messages_thread_id_created_at on public.chat_messages (thread_id, created_at);

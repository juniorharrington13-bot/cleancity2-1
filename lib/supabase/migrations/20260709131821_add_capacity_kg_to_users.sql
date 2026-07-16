alter table public.users
  add column capacity_kg numeric check (capacity_kg is null or capacity_kg >= 0);

comment on column public.users.capacity_kg is 'Max storage/sorting-zone capacity in kg. Only meaningful for center accounts; set by the center itself in their profile.';

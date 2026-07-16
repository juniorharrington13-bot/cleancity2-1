-- Lets a generator select multiple waste types for a single request. The
-- existing `waste_type` enum column stays as the primary/summary type
-- (set to 'mixed' when more than one type is picked, matching how the
-- rest of the app already treats mixed loads for rate lookups); this new
-- column keeps the exact set of types the generator actually picked.
alter table public.waste_requests add column if not exists waste_types text[];

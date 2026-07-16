create policy storage_buckets_authenticated_read on storage.buckets
  for select to authenticated using (true);

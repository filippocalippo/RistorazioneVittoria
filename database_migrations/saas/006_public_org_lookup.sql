-- Allow public (anon) read access to active organizations for join flow
create policy "Public can read basic org info by slug"
on organizations
for select
using (is_active = true and deleted_at is null);

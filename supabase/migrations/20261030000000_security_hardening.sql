-- Fixes from the security test of 2026-10-28.

-- 1. New tables, views, functions and sequences are no longer open to the public
--    automatically. Each one must now be granted on purpose (as all existing ones are).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated, public;

-- 2. Public buckets: files stay viewable by their public link, but nobody can list
--    the bucket any more. Users may only list their own folder (needed when an
--    account deletes its files).
drop policy if exists event_images_read on storage.objects;
create policy event_images_read on storage.objects for select to authenticated
  using (bucket_id = 'event-images' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- 3. The public organizer list no longer reveals each person's role (which
--    showed who the platform admin is) or their university.
drop view if exists public.organizer_profiles;
create view public.organizer_profiles with (security_invoker = false) as
select p.id, p.display_name, p.avatar_path,
       (select r.organization_name
          from public.organizer_requests r
         where r.user_id = p.id and r.status = 'approved'
         order by r.reviewed_at desc nulls last
         limit 1) as organization_name
from public.profiles p
where p.organizer_verified
  and p.role in ('organizer', 'tenant_admin', 'commercial_planner', 'platform_admin');
grant select on public.organizer_profiles to anon, authenticated;

-- 4. Fixed search_path for the remaining trigger functions.
alter function public.touch_updated_at() set search_path = '';
alter function public.events_lock_identity() set search_path = '';
alter function public.events_status_guard() set search_path = '';

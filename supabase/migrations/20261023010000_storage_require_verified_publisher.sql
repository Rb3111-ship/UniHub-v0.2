-- Security fix found by tools/security_tests.py:
-- uploading event images only checked the role, so an organizer who had NOT been
-- approved yet could still upload files (storage abuse). Require approval too.

create function public.is_verified_publisher() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.organizer_verified
      and p.role in ('organizer', 'tenant_admin', 'commercial_planner', 'platform_admin')
  )
$$;

revoke all on function public.is_verified_publisher() from public, anon, authenticated;
grant execute on function public.is_verified_publisher() to authenticated;

drop policy if exists event_images_write on storage.objects;
create policy event_images_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_verified_publisher()
  );

-- Updating/deleting your own files stays limited to your own folder.

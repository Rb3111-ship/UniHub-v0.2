-- Profile photos for organizers and admins (students do not get one).
--
-- Before this, profiles.avatar_path was writable by every user with any text.
-- Now it must point to the user's own file in the `avatars` bucket, and only
-- organizers/admins may set it.

create function public.may_have_avatar(p_role public.user_role, p_verified boolean)
returns boolean language sql immutable set search_path = public as $$
  select p_role in ('tenant_admin', 'platform_admin')
      or (p_role in ('organizer', 'commercial_planner') and p_verified)
$$;

-- Same rule for the signed-in user, used by the storage policies.
create function public.can_have_avatar() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and public.may_have_avatar(p.role, p.organizer_verified)
  )
$$;

revoke all on function public.may_have_avatar(public.user_role, boolean) from public, anon, authenticated;
revoke all on function public.can_have_avatar() from public, anon, authenticated;
-- The profile trigger runs as the signed-in user, so it needs the (harmless) rule check.
grant execute on function public.may_have_avatar(public.user_role, boolean) to authenticated;
grant execute on function public.can_have_avatar() to authenticated;

-- Clear any value that does not follow the new rules, then enforce them.
update public.profiles set avatar_path = null
where avatar_path is not null
  and (avatar_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/avatar-[0-9]{1,20}\.(jpg|png|webp)$'
       or split_part(avatar_path, '/', 1) <> id::text
       or not public.may_have_avatar(role, organizer_verified));

alter table public.profiles add constraint profiles_avatar_path_format
  check (avatar_path is null
         or avatar_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/avatar-[0-9]{1,20}\.(jpg|png|webp)$');
alter table public.profiles add constraint profiles_avatar_path_owner
  check (avatar_path is null or split_part(avatar_path, '/', 1) = id::text);

-- Only organizers/admins may have a photo; losing the role removes it.
create function public.profiles_avatar_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.avatar_path is not null and not public.may_have_avatar(new.role, new.organizer_verified) then
    if tg_op = 'UPDATE' and new.avatar_path is distinct from old.avatar_path then
      raise exception 'avatar_not_allowed' using errcode = '42501';
    end if;
    new.avatar_path := null;
  end if;
  return new;
end $$;
revoke all on function public.profiles_avatar_guard() from public, anon, authenticated;

create trigger profiles_avatar_guard before insert or update on public.profiles
  for each row execute function public.profiles_avatar_guard();

-- Storage: public read (photos are shown next to events), writes only into your
-- own folder and only if you may have a photo. 2 MB, images only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy avatars_read on storage.objects for select
  using (bucket_id = 'avatars');
create policy avatars_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.can_have_avatar()
  );
create policy avatars_modify on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
              and public.can_have_avatar());
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Show the organizer's photo on event pages.
create or replace view public.organizer_profiles with (security_invoker = false) as
select id, display_name, tenant_id, role, avatar_path
from public.profiles
where organizer_verified and role in ('organizer', 'tenant_admin', 'commercial_planner');

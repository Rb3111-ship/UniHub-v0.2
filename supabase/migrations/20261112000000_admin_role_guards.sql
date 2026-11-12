-- Pen test 2026-11-11, findings S1 and S4.
--
-- S1: a university admin could change the role of ANY account in their university,
--     including the platform admin and other university admins. Demoting them to
--     "student" also made them removable. Now a university admin may only change
--     accounts that are currently a student or an organizer.
-- S4: the last platform admin could demote themselves, leaving the platform without
--     any admin. Now that change is refused with "last_admin".

create or replace function public.admin_set_role(p_user uuid, p_role public.user_role, p_verified boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  select * into v_target from public.profiles where id = p_user;
  if v_me.id is null or v_target.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  if v_me.role = 'platform_admin' then
    null;
  elsif v_me.role = 'tenant_admin'
        and v_me.tenant_id is not null
        and v_target.tenant_id is not distinct from v_me.tenant_id
        and v_target.role in ('student', 'organizer')
        and p_role in ('student', 'organizer') then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if v_target.role = 'platform_admin' and p_role <> 'platform_admin' then
    -- Lock the admin rows so two admins demoting each other at the same moment
    -- cannot both get through.
    perform 1 from public.profiles where role = 'platform_admin' for update;
    if not exists (select 1 from public.profiles where role = 'platform_admin' and id <> p_user) then
      raise exception 'last_admin' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles set role = p_role, organizer_verified = p_verified where id = p_user;
end $$;

revoke all on function public.admin_set_role(uuid, public.user_role, boolean) from public, anon, authenticated;
grant execute on function public.admin_set_role(uuid, public.user_role, boolean) to authenticated;

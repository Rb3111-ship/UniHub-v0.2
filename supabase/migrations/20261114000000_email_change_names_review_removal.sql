-- Pen test 2026-11-11, findings S5, S6, S7, S8, B3 and B4.

-- ---------------------------------------------------------------------------
-- S7 + B3: display names.
--   * leading/trailing blanks removed, blank names refused
--   * no invisible characters or check marks
--   * "UniHub", "Admin" and "Moderator" are reserved for real admins
--   * a too-long or unusable name at sign-up no longer makes sign-up fail
-- ---------------------------------------------------------------------------
create function public.clean_display_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  -- Returns the tidied name, or NULL when the name may not be used.
  select case
    when n = '' then null
    when n ~ '[\u0001-\u001F\u007F​-‏‪-‮⁠-⁩﻿✓✔☑✅]' then null
    when lower(n) ~ '(unihub|admin|moderator)' then null
    else n
  end
  from (select left(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 80) as n) t
$$;

revoke all on function public.clean_display_name(text) from public, anon, authenticated;

create function public.profiles_name_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_clean text;
begin
  if new.display_name is not distinct from old.display_name then
    return new;
  end if;
  if new.role in ('platform_admin', 'tenant_admin') then
    -- Admins may use the reserved words, but still no blank names.
    v_clean := left(btrim(regexp_replace(coalesce(new.display_name, ''), '\s+', ' ', 'g')), 80);
    if v_clean = '' then v_clean := null; end if;
  else
    v_clean := public.clean_display_name(new.display_name);
  end if;
  if v_clean is null then
    raise exception 'name_not_allowed' using errcode = 'P0001';
  end if;
  new.display_name := v_clean;
  return new;
end $$;

revoke all on function public.profiles_name_guard() from public, anon, authenticated;

create trigger profiles_name_guard
  before update of display_name on public.profiles
  for each row execute function public.profiles_name_guard();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.blocked_emails b where b.email = lower(new.email)) then
    raise exception 'email_blocked' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, display_name)
  values (new.id, coalesce(
    public.clean_display_name(new.raw_user_meta_data ->> 'display_name'),
    public.clean_display_name(split_part(coalesce(new.email, ''), '@', 1)),
    'User'));

  -- Only trust the domain once the address is confirmed (OAuth users arrive confirmed).
  if new.email_confirmed_at is not null then
    perform public.assign_tenant_from_email(new.id, new.email);
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- S5: a blocked address could be reached by CHANGING an account's e-mail.
-- S6: university membership was never re-checked after an e-mail change.
--     Membership now follows the confirmed address: leaving the university's
--     domain ends it, moving onto it starts it.
-- ---------------------------------------------------------------------------
create function public.handle_user_email_change_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.blocked_emails b where b.email = lower(new.email)) then
    raise exception 'email_blocked' using errcode = 'P0001';
  end if;
  return new;
end $$;

create function public.handle_user_email_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_domain text := lower(split_part(new.email, '@', 2));
  v_tenant uuid;
begin
  select td.tenant_id into v_tenant
    from public.tenant_domains td
   where v_domain = td.domain or v_domain like '%.' || td.domain
   order by length(td.domain) desc
   limit 1;
  update public.profiles set tenant_id = v_tenant
   where id = new.id and tenant_id is distinct from v_tenant;
  return new;
end $$;

revoke all on function public.handle_user_email_change_check(), public.handle_user_email_changed()
  from public, anon, authenticated;

create trigger on_auth_user_email_change_check
  before update of email on auth.users
  for each row when (lower(new.email) is distinct from lower(old.email))
  execute function public.handle_user_email_change_check();

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row when (lower(new.email) is distinct from lower(old.email) and new.email_confirmed_at is not null)
  execute function public.handle_user_email_changed();

-- ---------------------------------------------------------------------------
-- S8: nobody could remove a single abusive review. Admins now can
--     (university admins only for events of their university).
-- ---------------------------------------------------------------------------
create function public.admin_delete_review(p_review uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_tenant uuid;
  v_found boolean;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select true, e.tenant_id into v_found, v_tenant
    from public.reviews r join public.events e on e.id = r.event_id
   where r.id = p_review;
  if v_found is not true then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if v_me.role = 'tenant_admin'
     and not (v_me.tenant_id is not null and v_tenant is not distinct from v_me.tenant_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  delete from public.reviews where id = p_review;
end $$;

revoke all on function public.admin_delete_review(uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_review(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- B4: the organizer's feedback list loaded the newest 100 reviews of the whole
--     platform and filtered afterwards. This returns only reviews of events the
--     caller manages. It runs with the caller's own permissions.
-- ---------------------------------------------------------------------------
create function public.my_event_feedback(p_limit integer default 100)
returns table (id uuid, event_id uuid, rating smallint, comment text, created_at timestamptz,
               is_verified boolean, claimed_attendance boolean, event_title text)
language sql
stable
security invoker
set search_path = ''
as $$
  select r.id, r.event_id, r.rating, r.comment, r.created_at, r.is_verified, r.claimed_attendance, e.title
    from public.events e
    join public.reviews r on r.event_id = e.id
   where public.can_manage_event(e.id)
   order by r.created_at desc
   limit least(greatest(coalesce(p_limit, 100), 1), 200)
$$;

revoke all on function public.my_event_feedback(integer) from public, anon, authenticated;
grant execute on function public.my_event_feedback(integer) to authenticated;

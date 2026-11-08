-- 1. Sign-ups whose e-mail code is never entered expire after 20 minutes, so the
--    address can be used again instead of being stuck on an unusable account.
-- 2. Admins can remove a user (and optionally block the address from signing up again).

-- 1. Expiring unconfirmed sign-ups -------------------------------------------
-- The clock restarts when a new code is sent (confirmation_sent_at), so asking for
-- a new code always gives a fresh 20 minutes.
create function public.purge_unconfirmed_signups()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  delete from auth.users u
   where u.email_confirmed_at is null
     and u.last_sign_in_at is null
     and not coalesce(u.is_anonymous, false)
     and greatest(u.created_at, coalesce(u.confirmation_sent_at, u.created_at)) < now() - interval '20 minutes'
     and not exists (select 1 from public.events e where e.organizer_id = u.id);
  get diagnostics v_count = row_count;
  return v_count;
end $$;

select cron.schedule('unihub-purge-unconfirmed', '*/5 * * * *', 'select public.purge_unconfirmed_signups()');

-- 2. Blocked addresses ---------------------------------------------------------
-- Only the definer functions read or write it; nobody else can see it.
create table public.blocked_emails (
  email      text primary key check (email = lower(email) and char_length(email) <= 320),
  blocked_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.blocked_emails enable row level security;

-- New accounts: refuse blocked addresses (the sign-up fails with a database error).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  if exists (select 1 from public.blocked_emails b where b.email = lower(new.email)) then
    raise exception 'email_blocked' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(new.email, ''), '@', 1)));

  -- Only trust the domain once the address is confirmed (OAuth users arrive confirmed).
  if new.email_confirmed_at is not null then
    perform public.assign_tenant_from_email(new.id, new.email);
  end if;
  return new;
end $$;

-- 3. Removing a user -------------------------------------------------------------
-- Platform admins may remove anyone except admins; university admins may remove
-- students and organizers of their own university. Admins must be demoted first.
-- The user's events are deleted too; people registered for upcoming ones are told
-- the event is cancelled. Returns how many events were deleted.
create function public.admin_delete_user(p_user uuid, p_block boolean default false)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_email text;
  v_events integer;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select * into v_target from public.profiles where id = p_user;
  select email into v_email from auth.users where id = p_user;
  if v_target.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_user = v_me.id then
    raise exception 'cannot_remove_self' using errcode = 'P0001';
  end if;
  if v_target.role in ('platform_admin', 'tenant_admin') then
    raise exception 'demote_first' using errcode = 'P0001';
  end if;
  if v_me.role = 'tenant_admin'
     and not (v_me.tenant_id is not null
              and v_target.tenant_id is not distinct from v_me.tenant_id
              and v_target.role in ('student', 'organizer')) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  -- The event rows are deleted below, so the message keeps only the title.
  insert into public.notifications (user_id, kind, event_title)
  select distinct r.user_id, 'event_cancelled', left(e.title, 200)
    from public.events e
    join public.registrations r on r.event_id = e.id
    join public.profiles p on p.id = r.user_id
   where e.organizer_id = p_user
     and e.status = 'published'
     and e.ends_at > now()
     and r.status in ('registered', 'waitlisted')
     and r.user_id <> p_user
     and p.notify_updates;

  delete from public.events where organizer_id = p_user;
  get diagnostics v_events = row_count;

  if p_block and v_email is not null then
    insert into public.blocked_emails (email, blocked_by) values (lower(v_email), v_me.id)
    on conflict (email) do nothing;
  end if;

  -- Cascades remove the profile, registrations, tickets, reviews, favourites and requests.
  delete from auth.users where id = p_user;
  return v_events;
end $$;

-- 4. The admin list shows whether the address is confirmed and how many events
--    the person organizes (shown before removing them).
drop function public.admin_list_users(text, integer);
create function public.admin_list_users(p_search text default null, p_limit integer default 50)
returns table(id uuid, display_name text, email text, role public.user_role, tenant_id uuid,
              organizer_verified boolean, created_at timestamptz, email_confirmed boolean, event_count integer)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles p where p.id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return query
    select p.id, p.display_name, u.email::text, p.role, p.tenant_id, p.organizer_verified, p.created_at,
           u.email_confirmed_at is not null,
           (select count(*)::integer from public.events e where e.organizer_id = p.id)
    from public.profiles p
    join auth.users u on u.id = p.id
    where (v_me.role = 'platform_admin' or p.tenant_id is not distinct from v_me.tenant_id)
      and (p_search is null or p_search = ''
           or p.display_name ilike '%' || p_search || '%' or u.email ilike '%' || p_search || '%')
    order by p.created_at desc
    limit least(greatest(p_limit, 1), 200);
end $$;

revoke all on function public.purge_unconfirmed_signups(), public.admin_delete_user(uuid, boolean),
  public.admin_list_users(text, integer) from public, anon, authenticated;
grant execute on function public.admin_delete_user(uuid, boolean), public.admin_list_users(text, integer) to authenticated;

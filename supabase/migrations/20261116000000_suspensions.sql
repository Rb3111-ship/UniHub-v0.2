-- Suspension: a reversible step before removing someone.
--
-- While an account is suspended:
--   * it cannot sign up for events, write reviews or report events
--   * it cannot publish, edit or scan (if it is an organizer)
--   * its events are hidden from the feed and take no new sign-ups
--     (people who already hold a ticket still see the event)
-- Nothing is deleted. Reinstating puts everything back as it was.
-- Suspending and reinstating each write a case file with the reports as evidence.

alter table public.profiles add column suspended_at timestamptz;
grant select (suspended_at) on public.profiles to authenticated;
-- No update grant: only admin_set_suspended() changes it.

create function public.is_suspended(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p where p.id = p_user and p.suspended_at is not null)
$$;

revoke all on function public.is_suspended(uuid) from public, anon, authenticated;
-- The event read rules below run as the visitor, so visitors must be able to call it.
grant execute on function public.is_suspended(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- A suspended organizer cannot publish or manage.
-- ---------------------------------------------------------------------------
create or replace function public.can_publish_for(p_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.organizer_verified
      and p.suspended_at is null
      and (
        (p_tenant is null and p.role = 'commercial_planner')
        or (p_tenant is not null and p.tenant_id = p_tenant and p.role in ('organizer', 'tenant_admin'))
        or p.role = 'platform_admin'
      )
  )
$$;

create or replace function public.is_verified_publisher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.organizer_verified
      and p.suspended_at is null
      and p.role in ('organizer', 'tenant_admin', 'commercial_planner', 'platform_admin')
  )
$$;

create or replace function public.can_manage_event(p_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.events e
    join public.profiles me on me.id = auth.uid()
    where e.id = p_event
      and (
        me.role = 'platform_admin'
        or (me.role = 'tenant_admin' and e.tenant_id is not null and e.tenant_id = me.tenant_id)
        or (
          e.organizer_id = me.id
          and me.organizer_verified
          and me.suspended_at is null
          and (
            (e.tenant_id is null and me.role = 'commercial_planner')
            or (e.tenant_id is not null and me.tenant_id = e.tenant_id and me.role in ('organizer', 'tenant_admin'))
          )
        )
      )
  )
$$;

-- ---------------------------------------------------------------------------
-- Events of a suspended organizer leave the feed.
-- (Unchanged: the organizer, admins and ticket holders still see them.)
-- ---------------------------------------------------------------------------
alter policy events_read_visitors on public.events
  using (status = 'published' and tenant_id is null and not public.is_suspended(organizer_id));

alter policy events_read_members on public.events
  using (
    (status = 'published'
     and (tenant_id is null or tenant_id = public.auth_tenant())
     and not public.is_suspended(organizer_id))
    or organizer_id = auth.uid()
    or public.can_manage_event(id)
    or (status in ('published', 'cancelled')
        and exists (select 1 from public.registrations r
                     where r.event_id = events.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
  );

-- ---------------------------------------------------------------------------
-- No new sign-ups, reviews or reports from a suspended account,
-- and no new sign-ups for a suspended organizer's events.
-- ---------------------------------------------------------------------------
create function public.suspension_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'registrations' then
    -- Only a NEW sign-up (or signing up again after cancelling). Cancelling,
    -- check-in and moving up from the waiting list stay possible.
    if new.status not in ('registered', 'waitlisted')
       or (tg_op = 'UPDATE' and old.status <> 'cancelled') then
      return new;
    end if;
    if public.is_suspended(new.user_id) then
      raise exception 'account_suspended' using errcode = 'P0001';
    end if;
    if exists (select 1 from public.events e where e.id = new.event_id and public.is_suspended(e.organizer_id)) then
      raise exception 'event_not_available' using errcode = 'P0002';
    end if;
  elsif tg_table_name = 'reviews' then
    if public.is_suspended(new.user_id) then
      raise exception 'account_suspended' using errcode = 'P0001';
    end if;
  elsif tg_table_name = 'event_reports' then
    if public.is_suspended(new.reporter_id) then
      raise exception 'account_suspended' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;

revoke all on function public.suspension_guard() from public, anon, authenticated;

create trigger registrations_suspension_guard
  before insert or update of status on public.registrations
  for each row execute function public.suspension_guard();

create trigger reviews_suspension_guard
  before insert on public.reviews
  for each row execute function public.suspension_guard();

create trigger event_reports_suspension_guard
  before insert on public.event_reports
  for each row execute function public.suspension_guard();

-- ---------------------------------------------------------------------------
-- Suspend / reinstate. Same rights as removing a user. A reason is required
-- for a suspension, and both steps go into the case files.
-- ---------------------------------------------------------------------------
alter table public.moderation_cases drop constraint moderation_cases_action_check;
alter table public.moderation_cases add constraint moderation_cases_action_check
  check (action in ('event_removed', 'user_removed', 'user_suspended', 'user_reinstated'));

create function public.admin_set_suspended(p_user uuid, p_suspend boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_email text;
  v_note text := nullif(btrim(left(coalesce(p_note, ''), 500)), '');
  v_evidence jsonb;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select * into v_target from public.profiles where id = p_user for update;
  if v_target.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_user = v_me.id then
    raise exception 'cannot_suspend_self' using errcode = 'P0001';
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
  if p_suspend is null or p_suspend = (v_target.suspended_at is not null) then
    raise exception 'no_change' using errcode = 'P0001';
  end if;
  if p_suspend and v_note is null then
    raise exception 'note_required' using errcode = 'P0001';
  end if;

  update public.profiles set suspended_at = case when p_suspend then now() end where id = p_user;

  select email into v_email from auth.users where id = p_user;
  v_evidence := public.reports_as_evidence(p_user);
  insert into public.moderation_cases (action, tenant_id, subject_user_id, subject_name, subject_email,
                                       note, decided_by, decided_by_name, report_count, evidence)
  values (case when p_suspend then 'user_suspended' else 'user_reinstated' end,
          v_target.tenant_id, p_user, v_target.display_name, coalesce(v_email, ''),
          v_note, v_me.id, v_me.display_name, jsonb_array_length(v_evidence), v_evidence);
end $$;

revoke all on function public.admin_set_suspended(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.admin_set_suspended(uuid, boolean, text) to authenticated;

-- A suspended account must not be given a publishing role by accident.
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

  if p_role in ('organizer', 'tenant_admin') and v_target.tenant_id is null then
    raise exception 'needs_university_email' using errcode = 'P0001';
  end if;

  if v_target.suspended_at is not null and p_role <> 'student' then
    raise exception 'account_suspended' using errcode = 'P0001';
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

-- The admin user list now says who is suspended.
drop function public.admin_list_users(text, integer);

create function public.admin_list_users(p_search text default null, p_limit integer default 50)
returns table (id uuid, display_name text, email text, role public.user_role, tenant_id uuid,
               organizer_verified boolean, created_at timestamptz, email_confirmed boolean,
               event_count integer, suspended_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
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
           (select count(*)::integer from public.events e where e.organizer_id = p.id),
           p.suspended_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where (v_me.role = 'platform_admin' or p.tenant_id is not distinct from v_me.tenant_id)
      and (p_search is null or p_search = ''
           or p.display_name ilike '%' || p_search || '%' or u.email ilike '%' || p_search || '%')
    order by p.created_at desc
    limit least(greatest(p_limit, 1), 200);
end $$;

revoke all on function public.admin_list_users(text, integer) from public, anon, authenticated;
grant execute on function public.admin_list_users(text, integer) to authenticated;

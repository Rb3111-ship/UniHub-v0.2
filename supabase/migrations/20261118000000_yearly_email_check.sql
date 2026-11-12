-- Yearly check that a university address still works.
--
-- People leave the university and lose the address, but nothing told us.
-- So once a year (counted per account, from the last time the address was
-- proven) every account that belongs to a university is asked to enter a code
-- sent to that address. They get 30 days. If they do not, nothing is deleted:
-- the account simply stops belonging to the university (public events only),
-- and organizers / university admins become students. Confirming later brings
-- the university back.
--
-- Permanent office addresses (AStA and the like) can be exempted by an admin.
-- Platform admins are never checked (that could lock the platform out).

alter table public.profiles
  add column email_checked_at timestamptz not null default now(),
  add column email_check_exempt boolean not null default false,
  add column email_check_notified_at timestamptz,
  add column email_check_lapsed_at timestamptz;

update public.profiles p
   set email_checked_at = coalesce(u.email_confirmed_at, p.created_at)
  from auth.users u
 where u.id = p.id;

grant select (email_checked_at, email_check_exempt, email_check_lapsed_at) on public.profiles to authenticated;
-- No update grants: only the functions below change these.

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                  'request_approved', 'request_rejected', 'event_removed',
                  'confirm_attendance', 'seat_released', 'review_prompt',
                  'account_suspended', 'account_reinstated',
                  'email_check_due', 'email_check_lapsed'));

-- ---------------------------------------------------------------------------
-- The person confirms. The proof is the sign-in itself: this only works in a
-- session that was started with an e-mailed code in the last 15 minutes.
-- (Supabase signs that fact into the session; it cannot be faked.)
-- ---------------------------------------------------------------------------
create function public.confirm_university_email()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (
    select 1
      from jsonb_array_elements(
             case when jsonb_typeof(auth.jwt() -> 'amr') = 'array' then auth.jwt() -> 'amr' else '[]'::jsonb end) a
     where a ->> 'method' in ('otp', 'magiclink', 'recovery')
       and (a ->> 'timestamp') ~ '^[0-9]{1,12}$'
       and (a ->> 'timestamp')::bigint > extract(epoch from now()) - 900
  ) then
    raise exception 'fresh_code_required' using errcode = 'P0001';
  end if;

  update public.profiles
     set email_checked_at = now(), email_check_notified_at = null, email_check_lapsed_at = null
   where id = v_uid;

  -- If the university was taken away after a missed check, give it back.
  select email into v_email from auth.users where id = v_uid;
  perform public.assign_tenant_from_email(v_uid, v_email);
end $$;

revoke all on function public.confirm_university_email() from public, anon, authenticated;
grant execute on function public.confirm_university_email() to authenticated;

-- A changed address was just proven (Supabase confirms new addresses), so the year starts again.
create function public.handle_user_email_rechecked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
     set email_checked_at = now(), email_check_notified_at = null, email_check_lapsed_at = null
   where id = new.id;
  return new;
end $$;

revoke all on function public.handle_user_email_rechecked() from public, anon, authenticated;

create trigger on_auth_user_email_rechecked
  after update of email on auth.users
  for each row
  when (lower(new.email::text) is distinct from lower(old.email::text) and new.email_confirmed_at is not null)
  execute function public.handle_user_email_rechecked();

-- ---------------------------------------------------------------------------
-- Daily job: ask those whose year is over; 30 days after asking, let the
-- university membership lapse.
-- ---------------------------------------------------------------------------
create function public.process_email_checks()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  with asked as (
    update public.profiles
       set email_check_notified_at = now()
     where tenant_id is not null
       and not email_check_exempt
       and role <> 'platform_admin'
       and email_checked_at < now() - interval '1 year'
       and email_check_notified_at is null
    returning id
  )
  insert into public.notifications (user_id, kind)
  select id, 'email_check_due' from asked;

  with lapsed as (
    update public.profiles
       set tenant_id = null,
           organizer_verified = case when role in ('organizer', 'tenant_admin') then false else organizer_verified end,
           role = case when role in ('organizer', 'tenant_admin') then 'student'::public.user_role else role end,
           email_check_lapsed_at = now()
     where tenant_id is not null
       and not email_check_exempt
       and role <> 'platform_admin'
       and email_checked_at < now() - interval '1 year'
       and email_check_notified_at < now() - interval '30 days'
    returning id
  )
  insert into public.notifications (user_id, kind)
  select id, 'email_check_lapsed' from lapsed;
end $$;

revoke all on function public.process_email_checks() from public, anon, authenticated;

select cron.schedule('unihub-email-checks', '20 4 * * *', $job$select public.process_email_checks()$job$);

-- ---------------------------------------------------------------------------
-- Admins: exempt a permanent organization address from the check.
-- Only organizers and university admins can be exempt, never plain students.
-- ---------------------------------------------------------------------------
create function public.admin_set_email_check(p_user uuid, p_exempt boolean)
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
        and v_target.role = 'organizer'
        and p_user <> v_me.id then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if p_exempt is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_exempt and (v_target.role not in ('organizer', 'tenant_admin') or v_target.tenant_id is null) then
    raise exception 'only_university_organizers' using errcode = 'P0001';
  end if;
  update public.profiles set email_check_exempt = p_exempt where id = p_user;
end $$;

revoke all on function public.admin_set_email_check(uuid, boolean) from public, anon, authenticated;
grant execute on function public.admin_set_email_check(uuid, boolean) to authenticated;

-- Approving a university organizer: the admin says whether this is a permanent
-- organization address (no yearly check) or a person (checked).
drop function public.review_organizer_request(uuid, boolean, text);

create function public.review_organizer_request(p_request uuid, p_approve boolean, p_note text default null,
                                                p_exempt boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_req public.organizer_requests%rowtype;
  v_target_tenant uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  select * into v_req from public.organizer_requests where id = p_request for update;
  if v_me.id is null or v_req.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'already_reviewed' using errcode = 'P0001';
  end if;

  v_target_tenant := public.user_tenant(v_req.user_id);
  if v_me.role = 'platform_admin' then
    null;
  elsif v_me.role = 'tenant_admin' and v_req.requested_role = 'organizer'
        and v_me.tenant_id is not null and v_target_tenant is not distinct from v_me.tenant_id then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  -- The applicant may have left the university address since applying.
  if p_approve and v_req.requested_role = 'organizer' and v_target_tenant is null then
    raise exception 'needs_university_email' using errcode = 'P0001';
  end if;

  if p_approve then
    -- Only ever upgrade students; never downgrade or overwrite an admin.
    update public.profiles
       set role = v_req.requested_role, organizer_verified = true,
           email_check_exempt = coalesce(p_exempt, false) and v_req.requested_role = 'organizer'
     where id = v_req.user_id and role = 'student';
  end if;

  update public.organizer_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.organizer_request_status,
         reviewed_by = v_me.id, reviewed_at = now(), review_note = nullif(btrim(p_note), '')
   where id = p_request;
end $$;

revoke all on function public.review_organizer_request(uuid, boolean, text, boolean) from public, anon, authenticated;
grant execute on function public.review_organizer_request(uuid, boolean, text, boolean) to authenticated;

-- Changing a role: an exemption only survives while the account stays an
-- organizer or university admin.
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

  update public.profiles
     set role = p_role, organizer_verified = p_verified,
         email_check_exempt = email_check_exempt and p_role in ('organizer', 'tenant_admin')
   where id = p_user;
end $$;

-- The admin user list shows the exemption and when the address was last proven.
drop function public.admin_list_users(text, integer);

create function public.admin_list_users(p_search text default null, p_limit integer default 50)
returns table (id uuid, display_name text, email text, role public.user_role, tenant_id uuid,
               organizer_verified boolean, created_at timestamptz, email_confirmed boolean,
               event_count integer, suspended_at timestamptz,
               email_check_exempt boolean, email_checked_at timestamptz)
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
           p.suspended_at, p.email_check_exempt, p.email_checked_at
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

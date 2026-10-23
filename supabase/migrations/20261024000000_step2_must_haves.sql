-- Step 2: event cancellation rules, organizer requests, admin tools, account deletion,
-- image path validation.

-- ---------------------------------------------------------------------------
-- 1. Event lifecycle
-- ---------------------------------------------------------------------------
-- Cancelled is final; a published event cannot go back to draft (people may hold tickets).
create function public.events_status_guard() returns trigger
language plpgsql as $$
begin
  if old.status = 'cancelled' then
    raise exception 'cancelled_is_final' using errcode = 'P0001';
  end if;
  if old.status = 'published' and new.status = 'draft' then
    raise exception 'cannot_unpublish' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger events_status_guard before update of status on public.events
  for each row when (old.status is distinct from new.status)
  execute function public.events_status_guard();

-- People holding a ticket can still see the event after it is cancelled (to see why
-- their ticket stopped working).
drop policy events_read on public.events;
create policy events_read on public.events for select to anon, authenticated
  using (
    (status = 'published' and (tenant_id is null or tenant_id = public.auth_tenant()))
    or public.can_manage_event(id)
    or (status in ('published', 'cancelled') and exists (
          select 1 from public.registrations r
          where r.event_id = events.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
  );

-- Images must live in the organizer's own folder of the event-images bucket.
alter table public.events add constraint events_image_path_format
  check (image_path is null
         or image_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9._-]{1,100}$');
alter table public.events add constraint events_image_path_owner
  check (image_path is null or split_part(image_path, '/', 1) = organizer_id::text);

-- ---------------------------------------------------------------------------
-- 2. Organizer requests
-- ---------------------------------------------------------------------------
create type public.organizer_request_status as enum ('pending', 'approved', 'rejected');

create table public.organizer_requests (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  email             text not null default '',
  requested_role    public.user_role not null check (requested_role in ('organizer', 'commercial_planner')),
  organization_name text not null check (char_length(btrim(organization_name)) between 2 and 120),
  message           text not null default '' check (char_length(message) <= 1000),
  status            public.organizer_request_status not null default 'pending',
  reviewed_by       uuid references public.profiles (id) on delete set null,
  reviewed_at       timestamptz,
  review_note       text check (review_note is null or char_length(review_note) <= 500),
  created_at        timestamptz not null default now()
);
create unique index organizer_requests_one_pending on public.organizer_requests (user_id) where status = 'pending';
create index organizer_requests_status_idx on public.organizer_requests (status, created_at);
alter table public.organizer_requests enable row level security;

create function public.user_tenant(p_user uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select tenant_id from public.profiles where id = p_user
$$;

create policy organizer_requests_read on public.organizer_requests for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_platform_admin()
    or (public.auth_role() = 'tenant_admin'
        and requested_role = 'organizer'
        and public.user_tenant(user_id) is not distinct from public.auth_tenant()
        and public.auth_tenant() is not null)
  );

create function public.request_organizer_access(p_role public.user_role, p_org text, p_message text default '')
returns public.organizer_requests
language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles%rowtype;
  v_req public.organizer_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_role not in ('organizer', 'commercial_planner') then
    raise exception 'invalid_role' using errcode = 'P0001';
  end if;
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.role <> 'student' then
    raise exception 'already_organizer' using errcode = 'P0001';
  end if;
  if p_role = 'organizer' and v_me.tenant_id is null then
    raise exception 'no_university' using errcode = 'P0001';
  end if;
  begin
    insert into public.organizer_requests (user_id, email, requested_role, organization_name, message)
    values (auth.uid(), coalesce(auth.jwt() ->> 'email', ''), p_role, p_org, coalesce(p_message, ''))
    returning * into v_req;
  exception when unique_violation then
    raise exception 'request_pending' using errcode = 'P0001';
  end;
  return v_req;
end $$;

create function public.review_organizer_request(p_request uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
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

  if p_approve then
    -- Only ever upgrade students; never downgrade or overwrite an admin.
    update public.profiles
       set role = v_req.requested_role, organizer_verified = true
     where id = v_req.user_id and role = 'student';
  end if;

  update public.organizer_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.organizer_request_status,
         reviewed_by = v_me.id, reviewed_at = now(), review_note = nullif(btrim(p_note), '')
   where id = p_request;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Admin: user list (with e-mail, which normal profile reads never expose)
-- ---------------------------------------------------------------------------
create function public.admin_list_users(p_search text default null, p_limit integer default 50)
returns table (id uuid, display_name text, email text, role public.user_role,
               tenant_id uuid, organizer_verified boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles p where p.id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return query
    select p.id, p.display_name, u.email::text, p.role, p.tenant_id, p.organizer_verified, p.created_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where (v_me.role = 'platform_admin' or p.tenant_id is not distinct from v_me.tenant_id)
      and (p_search is null or p_search = ''
           or p.display_name ilike '%' || p_search || '%' or u.email ilike '%' || p_search || '%')
    order by p.created_at desc
    limit least(greatest(p_limit, 1), 200);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Delete my account (GDPR)
-- ---------------------------------------------------------------------------
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_role public.user_role;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select role into v_role from public.profiles where id = v_uid;
  if exists (select 1 from public.events where organizer_id = v_uid) then
    raise exception 'has_events' using errcode = 'P0001';
  end if;
  if v_role = 'platform_admin'
     and (select count(*) from public.profiles where role = 'platform_admin') <= 1 then
    raise exception 'last_admin' using errcode = 'P0001';
  end if;
  -- Cascades remove the profile, registrations, tickets, reviews and requests.
  delete from auth.users where id = v_uid;
end $$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------
revoke all on function public.events_status_guard(), public.user_tenant(uuid),
  public.request_organizer_access(public.user_role, text, text),
  public.review_organizer_request(uuid, boolean, text),
  public.admin_list_users(text, integer), public.delete_my_account()
  from public, anon, authenticated;

grant execute on function public.user_tenant(uuid) to authenticated;  -- used inside RLS policy
grant execute on function public.request_organizer_access(public.user_role, text, text) to authenticated;
grant execute on function public.review_organizer_request(uuid, boolean, text) to authenticated;
grant execute on function public.admin_list_users(text, integer) to authenticated;
grant execute on function public.delete_my_account() to authenticated;

revoke all on public.organizer_requests from anon, authenticated;
grant select on public.organizer_requests to authenticated;

-- Pen test 2026-11-11, findings S2, B1, B2 (and B5 as a side effect).

-- ---------------------------------------------------------------------------
-- S2: an organizer whose rights were taken away could still edit their events,
--     publish drafts, scan tickets and read attendee lists, because owning an
--     event was enough. Now the owner must STILL be allowed to publish for that
--     event's university (or publicly, for commercial planners).
--     Admins are unaffected.
-- ---------------------------------------------------------------------------
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
          and (
            (e.tenant_id is null and me.role = 'commercial_planner')
            or (e.tenant_id is not null and me.tenant_id = e.tenant_id and me.role in ('organizer', 'tenant_admin'))
          )
        )
      )
  )
$$;

-- A former organizer may still SEE their own events and delete their own drafts,
-- nothing more. Checking organizer_id directly also lets a freshly inserted draft
-- be returned to its creator (B5).
alter policy events_read_members on public.events using (
  ((status = 'published') and ((tenant_id is null) or (tenant_id = public.auth_tenant())))
  or organizer_id = auth.uid()
  or public.can_manage_event(id)
  or ((status in ('published', 'cancelled'))
      and exists (select 1 from public.registrations r
                   where r.event_id = events.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
);

alter policy events_delete on public.events using (
  (organizer_id = auth.uid() or public.can_manage_event(id)) and status = 'draft'
);

-- ---------------------------------------------------------------------------
-- B2: the seat limit could be set below the number of people already registered.
-- ---------------------------------------------------------------------------
create function public.events_capacity_floor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_registered integer;
begin
  if new.capacity is not null and new.capacity is distinct from old.capacity then
    select count(*) into v_registered
      from public.registrations where event_id = new.id and status = 'registered';
    if new.capacity < v_registered then
      raise exception 'capacity_below_registered'
        using errcode = 'P0001', detail = v_registered::text;
    end if;
  end if;
  return new;
end $$;

revoke all on function public.events_capacity_floor() from public, anon, authenticated;

create trigger events_capacity_floor
  before update of capacity on public.events
  for each row execute function public.events_capacity_floor();

-- ---------------------------------------------------------------------------
-- B1: the app deleted the user's files and only then learned that the account
--     may not be deleted. The function can now be asked first (p_dry_run = true):
--     it runs the same checks and deletes nothing.
-- ---------------------------------------------------------------------------
drop function public.delete_my_account();

create function public.delete_my_account(p_dry_run boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
  if p_dry_run then
    return;
  end if;
  -- Cascades remove the profile, registrations, tickets, reviews and requests.
  delete from auth.users where id = v_uid;
end $$;

revoke all on function public.delete_my_account(boolean) from public, anon, authenticated;
grant execute on function public.delete_my_account(boolean) to authenticated;

-- "Are you still coming?" checks and richer organizer statistics.
--
-- About three days before an event, everyone holding a seat is asked to confirm.
-- "Yes" sets registrations.confirmed_at; "No" is a normal cancellation, so the
-- waitlist moves up as before. Organizers can opt in per event to free the seats
-- of people who never answered, 24 hours before the start, but only as many as
-- there are people waiting, and only for people who were actually asked.

-- 1. New columns.
alter table public.registrations
  add column if not exists confirmed_at     timestamptz,
  add column if not exists confirm_asked_at timestamptz,
  add column if not exists released_at      timestamptz;  -- seat freed because there was no answer

alter table public.events
  add column if not exists release_unconfirmed boolean not null default false;
grant update (release_unconfirmed) on public.events to authenticated;  -- insert is granted on the whole table

-- Re-registering after a cancellation starts over: not confirmed, not asked.
create function public.registrations_reset_confirmation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'cancelled' and new.status <> 'cancelled' then
    new.confirmed_at := null;
    new.confirm_asked_at := null;
    new.released_at := null;
  end if;
  return new;
end $$;
create trigger registrations_reset_confirmation before update of status on public.registrations
  for each row execute function public.registrations_reset_confirmation();

-- 2. New notification kinds.
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                  'request_approved', 'request_rejected', 'event_removed',
                  'confirm_attendance', 'seat_released'));

-- 3. The student's answer. "No" goes through cancel_registration in the app.
create function public.confirm_attendance(p_event_id uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  update public.registrations r
     set confirmed_at = coalesce(r.confirmed_at, now())
    from public.events e
   where r.event_id = p_event_id and r.user_id = v_uid and r.status = 'registered'
     and e.id = r.event_id and e.status = 'published' and e.ends_at > now()
  returning r.confirmed_at into v_at;
  if v_at is null then
    raise exception 'not_registered' using errcode = 'P0001';
  end if;
  return v_at;
end $$;

-- 4. Scheduled work (every 10 minutes).
create function public.process_attendance_checks() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_asked integer;
  v_event record;
  v_reg record;
begin
  -- a) Ask: events 26 to 72 hours away. Skip people who registered in the last
  --    12 hours (they just decided) and organizers of their own event.
  with asked as (
    update public.registrations r
       set confirm_asked_at = now()
      from public.events e
     where e.id = r.event_id and e.status = 'published'
       and e.starts_at > now() + interval '26 hours' and e.starts_at <= now() + interval '72 hours'
       and r.status = 'registered' and r.confirmed_at is null and r.confirm_asked_at is null
       and r.created_at < now() - interval '12 hours'
       and r.user_id is distinct from e.organizer_id
    returning r.user_id, e.id as event_id, e.title)
  insert into public.notifications (user_id, kind, event_id, event_title)
  select user_id, 'confirm_attendance', event_id, left(title, 200) from asked;
  get diagnostics v_asked = row_count;

  -- b) Release: events that opted in, starting within 24 hours, with people waiting.
  for v_event in
    select e.id, e.title from public.events e
     where e.release_unconfirmed and e.status = 'published'
       and e.starts_at > now() and e.starts_at <= now() + interval '24 hours'
       and exists (select 1 from public.registrations w where w.event_id = e.id and w.status = 'waitlisted')
       and exists (select 1 from public.registrations u where u.event_id = e.id and u.status = 'registered'
                     and u.confirmed_at is null and u.confirm_asked_at < now() - interval '12 hours')
  loop
    perform 1 from public.events where id = v_event.id for update;  -- same lock as register/cancel
    -- One seat per waiting person; those who registered last give way first.
    for v_reg in
      select u.id, u.user_id from public.registrations u
       where u.event_id = v_event.id and u.status = 'registered'
         and u.confirmed_at is null and u.confirm_asked_at < now() - interval '12 hours'
         and not exists (select 1 from public.tickets t where t.registration_id = u.id and t.checked_in_at is not null)
       order by u.created_at desc
       limit (select count(*) from public.registrations w where w.event_id = v_event.id and w.status = 'waitlisted')
    loop
      update public.registrations set status = 'cancelled', cancelled_at = now(), released_at = now()
       where id = v_reg.id;
      update public.tickets set voided_at = now() where registration_id = v_reg.id;
      insert into public.notifications (user_id, kind, event_id, event_title)
      values (v_reg.user_id, 'seat_released', v_event.id, left(v_event.title, 200));
    end loop;
    perform public.promote_waitlist(v_event.id);
  end loop;

  return v_asked;
end $$;

select cron.schedule('unihub-attendance-checks', '*/10 * * * *', 'select public.process_attendance_checks()');

-- 5. Statistics. Appends columns to the existing view (security_invoker, so a
--    planner only sees their own events and rows).
create or replace view public.event_stats with (security_invoker = true) as
select e.id as event_id,
       e.title,
       e.capacity,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'registered')::integer as registered,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'waitlisted')::integer as waitlisted,
       (select count(*) from public.tickets t where t.event_id = e.id and t.checked_in_at is not null)::integer as checked_in,
       e.starts_at,
       e.ends_at,
       e.status,
       (select round(avg(v.rating)::numeric, 2) from public.reviews v where v.event_id = e.id and v.is_verified) as avg_rating,
       (select count(*) from public.reviews v where v.event_id = e.id and v.is_verified)::integer as review_count,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'registered'
                                                     and r.confirmed_at is not null)::integer as confirmed,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'cancelled')::integer as cancelled,
       (select count(*) from public.registrations r where r.event_id = e.id and r.released_at is not null)::integer as released,
       e.requires_qr,
       e.release_unconfirmed
from public.events e
where public.can_manage_event(e.id);

grant select on public.event_stats to authenticated;

-- Details for one event page: sign-ups per day and the star distribution.
create function public.event_insights(p_event_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_manage_event(p_event_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'signups', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'count', d.n) order by d.day)
        from (select (r.created_at at time zone 'Europe/Berlin')::date as day, count(*) as n
                from public.registrations r where r.event_id = p_event_id
               group by 1) d), '[]'::jsonb),
    'stars', (select jsonb_build_array(
                count(*) filter (where v.rating = 1), count(*) filter (where v.rating = 2),
                count(*) filter (where v.rating = 3), count(*) filter (where v.rating = 4),
                count(*) filter (where v.rating = 5))
                from public.reviews v where v.event_id = p_event_id),
    'stars_verified', (select count(*) from public.reviews v where v.event_id = p_event_id and v.is_verified),
    'asked', (select count(*) from public.registrations r
               where r.event_id = p_event_id and r.confirm_asked_at is not null),
    'declined', (select count(*) from public.registrations r
                  where r.event_id = p_event_id and r.status = 'cancelled'
                    and r.confirm_asked_at is not null and r.released_at is null
                    and r.cancelled_at > r.confirm_asked_at));
end $$;

-- 6. Who may call what.
revoke all on function public.registrations_reset_confirmation(), public.confirm_attendance(uuid),
  public.process_attendance_checks(), public.event_insights(uuid)
  from public, anon, authenticated;
grant execute on function public.confirm_attendance(uuid), public.event_insights(uuid) to authenticated;

-- A cancelled event is no longer final: its organizer can take it back to a
-- draft, change it (new date...) and publish it again.
--
-- Rules:
--   * cancelled -> draft is the only way out of "cancelled"
--   * not for events an admin removed after reports (otherwise "Remove event"
--     would mean nothing), and not while reports about it are still open
--   * the old sign-ups do not come back: those people were told the event is
--     cancelled, so their registrations end and they register again if they
--     still want to come. Reviews already written stay.

create or replace function public.events_lock_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- A cancelled event cannot be changed, except by taking it back to a draft.
  if old.status = 'cancelled' and new.status is distinct from 'draft' then
    raise exception 'cancelled_is_final' using errcode = 'P0001';
  end if;
  if new.organizer_id is distinct from old.organizer_id
     or new.tenant_id is distinct from old.tenant_id then
    raise exception 'organizer_and_tenant_are_immutable' using errcode = '42501';
  end if;
  return new;
end $$;

create or replace function public.events_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'cancelled' then
    if new.status <> 'draft' then
      raise exception 'cancelled_is_final' using errcode = 'P0001';
    end if;
    if old.moderated_at is not null then
      raise exception 'removed_by_admin' using errcode = 'P0001';
    end if;
    if public.event_has_open_reports(old.id) then
      raise exception 'has_open_reports' using errcode = 'P0001';
    end if;
  end if;
  if old.status = 'published' and new.status = 'draft' then
    raise exception 'cannot_unpublish' using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function public.events_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    perform public.notify_event_attendees(new.id, 'event_cancelled', 'updates');
    if new.moderated_at is not null and old.moderated_at is null and new.organizer_id is not null then
      insert into public.notifications (user_id, kind, event_id, event_title)
      values (new.organizer_id, 'event_removed', new.id, left(new.title, 200));
    end if;
  elsif old.status = 'cancelled' and new.status = 'draft' then
    -- Reopened: the old sign-ups end here (see the rules at the top).
    update public.tickets set voided_at = now()
     where event_id = new.id and voided_at is null;
    update public.registrations set status = 'cancelled', cancelled_at = now()
     where event_id = new.id and status in ('registered', 'waitlisted');
  elsif new.status = 'published' and old.status = 'published'
        and (new.starts_at is distinct from old.starts_at or new.location is distinct from old.location) then
    perform public.notify_event_attendees(new.id, 'event_changed', 'updates');
  end if;
  return null;
end $$;

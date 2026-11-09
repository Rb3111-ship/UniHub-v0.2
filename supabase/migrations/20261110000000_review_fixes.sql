-- Fixes from the pre-launch review.
-- 1. The waitlist only moves up while the event is published and not over yet
--    (no "You got a spot!" for an event that already ended or was cancelled).
-- 2. Cancelled events cannot be reviewed.
-- 3. A cancelled event is frozen: its organizer can no longer edit it (ticket
--    holders still see it, so its text must stay as it was).

create or replace function public.promote_waitlist(p_event uuid)
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  v_capacity integer;
  v_taken integer;
  v_next uuid;
begin
  select capacity into v_capacity from public.events
   where id = p_event and status = 'published' and ends_at > now();
  if not found then
    return;
  end if;
  loop
    select count(*) into v_taken
      from public.registrations where event_id = p_event and status = 'registered';
    exit when v_capacity is not null and v_taken >= v_capacity;

    select id into v_next from public.registrations
      where event_id = p_event and status = 'waitlisted'
      order by created_at limit 1;
    exit when v_next is null;

    update public.registrations set status = 'registered' where id = v_next;
    perform public.issue_ticket(v_next);
  end loop;
end $$;

create or replace function public.submit_review(p_event_id uuid, p_rating integer, p_comment text,
                                                p_claimed_attendance boolean default false)
returns public.reviews language plpgsql security definer set search_path = 'public' as $$
declare
  v_uid uuid := auth.uid();
  v_event public.events%rowtype;
  v_ticket public.tickets%rowtype;
  v_review public.reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_event from public.events where id = p_event_id;
  if not found or not v_event.allow_reviews or v_event.status = 'cancelled' then
    raise exception 'reviews_not_allowed' using errcode = 'P0001';
  end if;
  if v_event.starts_at > now() then
    raise exception 'event_not_started' using errcode = 'P0001';
  end if;

  select * into v_ticket from public.tickets
    where event_id = p_event_id and user_id = v_uid and voided_at is null;
  if not found then
    raise exception 'no_ticket' using errcode = 'P0001';
  end if;
  if v_event.requires_qr and v_ticket.checked_in_at is null then
    raise exception 'check_in_required' using errcode = 'P0001';
  end if;

  -- "Verified" means the door scan happened, regardless of the event's QR setting.
  insert into public.reviews (event_id, ticket_id, user_id, rating, comment, claimed_attendance, is_verified)
  values (p_event_id, v_ticket.id, v_uid, p_rating, p_comment,
          p_claimed_attendance or v_ticket.checked_in_at is not null,
          v_ticket.checked_in_at is not null)
  returning * into v_review;  -- unique(ticket_id) rejects a second review
  return v_review;
end $$;

create or replace function public.events_lock_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status = 'cancelled' then
    raise exception 'cancelled_is_final' using errcode = 'P0001';
  end if;
  if new.organizer_id is distinct from old.organizer_id
     or new.tenant_id is distinct from old.tenant_id then
    raise exception 'organizer_and_tenant_are_immutable' using errcode = '42501';
  end if;
  return new;
end $$;

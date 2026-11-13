-- Events without QR check-in ("open entry").
--
-- 1. They cannot be scanned at all. Before this, the ticket still carried a QR
--    code, an organizer could scan it, and that scan silently turned the
--    person's review into a "verified" one.
-- 2. Their reviews count: anyone with a ticket may review, the review is
--    public and its stars are counted. (Owner's decision 2026-11-13: the few
--    people who review without having been there do not outweigh the value of
--    the ratings.) At events WITH check-in nothing changes: only people who
--    were scanned can review.
--
-- "is_verified" keeps its technical meaning: public and counted in the stars.

create or replace function public.check_in_ticket(p_code text, p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.tickets%rowtype;
  v_event public.events%rowtype;
  v_name text;
  v_updated integer;
begin
  if v_uid is null or not public.can_manage_event(p_event_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select * into v_event from public.events where id = p_event_id;
  if not v_event.requires_qr then
    raise exception 'no_check_in' using errcode = 'P0001';
  end if;
  select * into v_ticket from public.tickets where code = p_code;

  if not found then
    insert into public.scan_log (event_id, scanned_by, result) values (p_event_id, v_uid, 'invalid');
    return jsonb_build_object('ok', false, 'result', 'invalid');
  end if;

  select display_name into v_name from public.profiles where id = v_ticket.user_id;

  if v_ticket.event_id <> p_event_id then
    insert into public.scan_log (event_id, ticket_id, scanned_by, result)
      values (p_event_id, v_ticket.id, v_uid, 'wrong_event');
    return jsonb_build_object('ok', false, 'result', 'wrong_event');
  end if;

  if v_ticket.voided_at is not null or v_event.status = 'cancelled' then
    insert into public.scan_log (event_id, ticket_id, scanned_by, result)
      values (p_event_id, v_ticket.id, v_uid, 'cancelled');
    return jsonb_build_object('ok', false, 'result', 'cancelled');
  end if;

  -- Conditional update makes concurrent double-scans safe: only one wins.
  update public.tickets set checked_in_at = now(), checked_in_by = v_uid
    where id = v_ticket.id and checked_in_at is null;
  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    insert into public.scan_log (event_id, ticket_id, scanned_by, result)
      values (p_event_id, v_ticket.id, v_uid, 'already_used');
    return jsonb_build_object('ok', false, 'result', 'already_used',
                              'attendee_name', v_name, 'ticket_number', v_ticket.ticket_number);
  end if;

  insert into public.scan_log (event_id, ticket_id, scanned_by, result)
    values (p_event_id, v_ticket.id, v_uid, 'granted');
  return jsonb_build_object('ok', true, 'result', 'granted',
                            'attendee_name', v_name, 'ticket_number', v_ticket.ticket_number);
end $$;

create or replace function public.submit_review(p_event_id uuid, p_rating integer, p_comment text,
                                                p_claimed_attendance boolean default false)
returns public.reviews
language plpgsql
security definer
set search_path = public
as $$
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

  -- Past the checks above, every review counts: at check-in events the person
  -- was scanned, at open-entry events a ticket is enough.
  insert into public.reviews (event_id, ticket_id, user_id, rating, comment, claimed_attendance, is_verified)
  values (p_event_id, v_ticket.id, v_uid, p_rating, p_comment,
          p_claimed_attendance or v_ticket.checked_in_at is not null,
          true)
  returning * into v_review;  -- unique(ticket_id) rejects a second review
  return v_review;
end $$;

-- Reviews written under the old rule at open-entry events now count too.
update public.reviews r
   set is_verified = true
  from public.events e
 where e.id = r.event_id and not e.requires_qr and not r.is_verified;

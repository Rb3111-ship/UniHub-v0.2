-- "How was it?" notifications: about an hour after an event ends, everyone who may
-- review it (see submit_review) is invited once. Not for cancelled events, events
-- without reviews, people on the waitlist, people who already reviewed, or - when
-- the event used door scanning - people who were never scanned in.

-- 1. Remember who was asked, so deleting the notification does not bring it back.
alter table public.registrations
  add column if not exists review_asked_at timestamptz;

-- 2. New notification kind.
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                  'request_approved', 'request_rejected', 'event_removed',
                  'confirm_attendance', 'seat_released', 'review_prompt'));

-- 3. The job (every 10 minutes). Events that ended more than 3 days ago are skipped,
--    so nobody gets invitations for old events. Uses the "reminders" preference.
create function public.queue_review_prompts() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  with asked as (
    update public.registrations r
       set review_asked_at = now()
      from public.events e, public.profiles p
     where e.id = r.event_id and p.id = r.user_id
       and e.status = 'published' and e.allow_reviews
       and e.ends_at <= now() - interval '1 hour' and e.ends_at > now() - interval '3 days'
       and r.status = 'registered' and r.review_asked_at is null
       and r.user_id is distinct from e.organizer_id
       and p.notify_reminders
       and exists (select 1 from public.tickets t
                    where t.registration_id = r.id and t.voided_at is null
                      and (not e.requires_qr or t.checked_in_at is not null))
       and not exists (select 1 from public.reviews v where v.event_id = e.id and v.user_id = r.user_id)
    returning r.user_id, e.id as event_id, e.title)
  insert into public.notifications (user_id, kind, event_id, event_title)
  select user_id, 'review_prompt', event_id, left(title, 200) from asked;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function public.queue_review_prompts() from public, anon, authenticated;

select cron.schedule('unihub-review-prompts', '*/10 * * * *', 'select public.queue_review_prompts()');

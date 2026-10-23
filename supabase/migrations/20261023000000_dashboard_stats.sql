-- Planner dashboard: richer per-event numbers.
-- Appends columns to the existing view (allowed by CREATE OR REPLACE VIEW).
-- security_invoker means a planner only ever sees events they may manage, and the
-- counts below only include rows their Row Level Security allows them to read.

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
       (select count(*) from public.reviews v where v.event_id = e.id and v.is_verified)::integer as review_count
from public.events e
where public.can_manage_event(e.id);

grant select on public.event_stats to authenticated;

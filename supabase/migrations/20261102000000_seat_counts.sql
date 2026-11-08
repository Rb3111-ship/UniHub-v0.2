-- Taken seats for many events at once, for "12 seats left" labels on the feed.
-- Same visibility rule as event_registered_count: published events that are
-- public or belong to the caller's university. Returns counts only, never who.
create function public.event_seat_counts(p_event_ids uuid[])
returns table (event_id uuid, registered integer)
language sql stable security definer set search_path = '' as $$
  select e.id, (select count(*)::integer from public.registrations r
                 where r.event_id = e.id and r.status = 'registered')
    from public.events e
   where e.id = any(p_event_ids[1:500])
     and e.status = 'published'
     and (e.tenant_id is null or e.tenant_id = public.auth_tenant());
$$;

revoke all on function public.event_seat_counts(uuid[]) from public, anon, authenticated;
grant execute on function public.event_seat_counts(uuid[]) to anon, authenticated;

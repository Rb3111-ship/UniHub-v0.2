-- Fix for 20261024000000: the combined events_read policy referenced the registrations
-- table, which signed-out visitors may not read. Postgres then raised "permission denied"
-- for EVERY events query by a visitor, which would have broken guest browsing.
-- Split it: visitors see public events only; signed-in users get the fuller rule.

drop policy events_read on public.events;

create policy events_read_visitors on public.events for select to anon
  using (status = 'published' and tenant_id is null);

create policy events_read_members on public.events for select to authenticated
  using (
    (status = 'published' and (tenant_id is null or tenant_id = public.auth_tenant()))
    or public.can_manage_event(id)
    or (status in ('published', 'cancelled') and exists (
          select 1 from public.registrations r
          where r.event_id = events.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
  );

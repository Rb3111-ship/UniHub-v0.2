-- Organizers may delete their cancelled events (before: drafts only), so a
-- cancelled plan does not sit on the dashboard forever.
-- Two limits protect evidence:
--   * not while there are OPEN reports about the event (an admin must decide first)
--   * not while the organizer is suspended (an investigation is running)
-- Events removed by an admin already have a case file with the reports, so
-- deleting those afterwards loses nothing.

create function public.event_has_open_reports(p_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.event_reports r where r.event_id = p_event and r.status = 'open')
$$;

revoke all on function public.event_has_open_reports(uuid) from public, anon, authenticated;
-- The delete rule below runs as the signed-in user.
grant execute on function public.event_has_open_reports(uuid) to authenticated;

alter policy events_delete on public.events
  using (
    (organizer_id = auth.uid() or public.can_manage_event(id))
    and not public.is_suspended(auth.uid())
    and (status = 'draft'
         or (status = 'cancelled' and not public.event_has_open_reports(id)))
  );

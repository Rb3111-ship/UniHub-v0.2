-- Only accounts that belong to a university can register for events, public
-- events included. Organizers on this platform address students; a ticket in
-- the hands of an arbitrary outside account is not what they expect.
-- Accounts without a university can still browse public events and can still
-- apply to become (commercial) organizers. Registrations made before this
-- rule stay valid.

create or replace function public.register_for_event(p_event_id uuid)
returns public.registrations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_event public.events%rowtype;
  v_reg public.registrations%rowtype;
  v_exists boolean;
  v_taken integer;
  v_status public.registration_status;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if public.auth_tenant() is null then
    raise exception 'university_email_required' using errcode = 'P0001';
  end if;

  select * into v_event from public.events where id = p_event_id for update;  -- serialises capacity checks
  if not found or v_event.status <> 'published'
     or (v_event.tenant_id is not null and v_event.tenant_id is distinct from public.auth_tenant()) then
    raise exception 'event_not_available' using errcode = 'P0002';
  end if;
  if v_event.organizer_id = v_uid then
    raise exception 'own_event' using errcode = 'P0001';
  end if;
  if v_event.ends_at < now() then
    raise exception 'event_over' using errcode = 'P0001';
  end if;
  if v_event.price_cents > 0 then
    raise exception 'paid_events_not_supported_yet' using errcode = 'P0001';
  end if;

  select * into v_reg from public.registrations where event_id = p_event_id and user_id = v_uid;
  v_exists := found;
  if v_exists and v_reg.status in ('registered', 'waitlisted') then
    return v_reg;  -- idempotent
  end if;

  select count(*) into v_taken
    from public.registrations where event_id = p_event_id and status = 'registered';
  v_status := case when v_event.capacity is not null and v_taken >= v_event.capacity
                   then 'waitlisted' else 'registered' end;

  if v_exists then
    update public.registrations
      set status = v_status, cancelled_at = null, created_at = now()
      where id = v_reg.id returning * into v_reg;
  else
    insert into public.registrations (event_id, user_id, status)
      values (p_event_id, v_uid, v_status) returning * into v_reg;
  end if;

  if v_status = 'registered' then
    perform public.issue_ticket(v_reg.id);
  end if;
  return v_reg;
end $$;

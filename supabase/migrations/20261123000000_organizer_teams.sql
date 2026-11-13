-- Organizer teams.
--
-- One account on one phone cannot check in 200 guests. An organizer can now
-- invite other UniHub accounts as teammates and give each of them one or both
-- of two permissions:
--   scan : check guests in at the organizer's events
--   edit : create and edit the organizer's events
--
-- Rules:
--   * The events stay the organizer's (organizer_id never changes). Who
--     created / last changed an event is recorded (created_by / updated_by).
--   * Only the organizer (or an admin) can cancel, reopen or delete an event
--     and manage the team.
--   * Teammates of a university organizer must belong to the same university,
--     at the invitation and for as long as they act.
--   * At most 15 teammates (invited + accepted).
--   * A suspended teammate has no team rights. A suspended or demoted
--     organizer freezes the whole team. Nothing is deleted; the rights come
--     back when the reason is gone.
--   * An invitation must be accepted by the invited person.

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.profiles (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  can_scan boolean not null default true,
  can_edit boolean not null default false,
  status text not null default 'invited' check (status in ('invited', 'active')),
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  unique (organizer_id, member_id),
  check (organizer_id <> member_id),
  check (can_scan or can_edit)
);

create index team_members_member_idx on public.team_members (member_id);

alter table public.team_members enable row level security;
-- No policies and no grants: only the functions below read or write it.
revoke all on table public.team_members from public, anon, authenticated;

alter table public.events
  add column created_by uuid references public.profiles (id) on delete set null,
  add column updated_by uuid references public.profiles (id) on delete set null;

-- Existing events were created by their organizer. The event triggers are
-- switched off for this one statement: it must not count as an edit (cancelled
-- events refuse edits) and must not notify anyone.
alter table public.events disable trigger user;
update public.events set created_by = organizer_id, updated_by = organizer_id where created_by is null;
alter table public.events enable trigger user;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                  'request_approved', 'request_rejected', 'event_removed',
                  'confirm_attendance', 'seat_released', 'review_prompt',
                  'account_suspended', 'account_reinstated',
                  'email_check_due', 'email_check_lapsed',
                  'team_invite'));

-- ---------------------------------------------------------------------------
-- The one question everything else asks: may the signed-in user act for this
-- organizer? p_what: 'scan', 'edit' or 'any'.
-- ---------------------------------------------------------------------------
create function public.team_can(p_organizer uuid, p_what text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.team_members t
      join public.profiles m on m.id = t.member_id
      join public.profiles o on o.id = t.organizer_id
     where t.organizer_id = p_organizer
       and t.member_id = auth.uid()
       and t.status = 'active'
       and case p_what when 'scan' then t.can_scan when 'edit' then t.can_edit when 'any' then true else false end
       and m.suspended_at is null
       and o.suspended_at is null
       and o.organizer_verified
       and o.role in ('organizer', 'commercial_planner', 'tenant_admin', 'platform_admin')
       -- a university organizer's team is from that university
       and (o.role in ('commercial_planner', 'platform_admin') or m.tenant_id is not distinct from o.tenant_id)
  )
$$;

revoke all on function public.team_can(uuid, text) from public, anon, authenticated;
-- Used inside the event rules, which also run for visitors.
grant execute on function public.team_can(uuid, text) to anon, authenticated;

-- A teammate creates events only where the organizer may publish.
create function public.team_can_publish(p_organizer uuid, p_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.team_can(p_organizer, 'edit')
     and exists (
       select 1 from public.profiles o
        where o.id = p_organizer
          and ((p_tenant is null and o.role in ('commercial_planner', 'platform_admin'))
               or (p_tenant is not null and o.tenant_id = p_tenant
                   and o.role in ('organizer', 'tenant_admin', 'platform_admin')))
     )
$$;

revoke all on function public.team_can_publish(uuid, uuid) from public, anon, authenticated;
grant execute on function public.team_can_publish(uuid, uuid) to authenticated;

-- For the poster folder rules: the folder name is the organizer's id.
create function public.team_can_edit_folder(p_folder text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_folder ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           then public.team_can(p_folder::uuid, 'edit')
           else false
         end
$$;

revoke all on function public.team_can_edit_folder(text) from public, anon, authenticated;
grant execute on function public.team_can_edit_folder(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Events: teammates see the organizer's events; editors may create and change
-- them. Deleting stays with the organizer (events_delete is unchanged).
-- ---------------------------------------------------------------------------
alter policy events_read_members on public.events
  using (
    (status = 'published'
     and (tenant_id is null or tenant_id = public.auth_tenant())
     and not public.is_suspended(organizer_id))
    or organizer_id = auth.uid()
    or public.can_manage_event(id)
    or public.team_can(organizer_id, 'any')
    or (status in ('published', 'cancelled')
        and exists (select 1 from public.registrations r
                     where r.event_id = events.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
  );

alter policy events_insert on public.events
  with check (
    (organizer_id = auth.uid() and public.can_publish_for(tenant_id))
    or (organizer_id <> auth.uid() and public.team_can_publish(organizer_id, tenant_id))
  );

alter policy events_update on public.events
  using (public.can_manage_event(id) or public.team_can(organizer_id, 'edit'))
  with check (public.can_manage_event(id) or public.team_can(organizer_id, 'edit'));

-- Who created / last changed an event. Set by the server, never by the app.
create function public.events_stamp_author()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.organizer_id);
    new.updated_by := new.created_by;
  else
    new.created_by := old.created_by;
    if auth.uid() is not null then
      new.updated_by := auth.uid();
    end if;
  end if;
  return new;
end $$;

revoke all on function public.events_stamp_author() from public, anon, authenticated;

create trigger events_stamp_author
  before insert or update on public.events
  for each row execute function public.events_stamp_author();

-- Cancelling, reopening and publishing again are the organizer's decisions.
create or replace function public.events_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and not public.can_manage_event(old.id) then
    raise exception 'only_organizer' using errcode = '42501';
  end if;
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

-- Posters live in the organizer's folder; an editor may put them there.
alter policy event_images_write on storage.objects
  with check (
    bucket_id = 'event-images'
    and (((storage.foldername(name))[1] = auth.uid()::text and public.is_verified_publisher())
         or public.team_can_edit_folder((storage.foldername(name))[1]))
  );

alter policy event_images_modify on storage.objects
  using (
    bucket_id = 'event-images'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.team_can_edit_folder((storage.foldername(name))[1]))
  );

alter policy event_images_delete on storage.objects
  using (
    bucket_id = 'event-images'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.team_can_edit_folder((storage.foldername(name))[1]))
  );

alter policy event_images_read on storage.objects
  using (
    bucket_id = 'event-images'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.team_can_edit_folder((storage.foldername(name))[1]))
  );

-- ---------------------------------------------------------------------------
-- Scanning: the organizer, an admin, or a teammate with the scan permission.
-- scan_log.scanned_by / tickets.checked_in_by record who it was.
-- ---------------------------------------------------------------------------
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
  select * into v_event from public.events where id = p_event_id;
  if v_uid is null or v_event.id is null
     or not (public.can_manage_event(p_event_id) or public.team_can(v_event.organizer_id, 'scan')) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

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
  -- (Two teammates scanning the same ticket at the same moment: one gets
  -- "granted", the other "already used".)
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

-- ---------------------------------------------------------------------------
-- Managing the team.
-- ---------------------------------------------------------------------------

-- Invites the account with this e-mail address. To not reveal who has an
-- account, an unknown address (or one from another university, for a
-- university organizer) is answered exactly like a successful invitation.
create function public.team_invite(p_email text, p_can_scan boolean, p_can_edit boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_target_id uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or not public.is_verified_publisher() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if not (coalesce(p_can_scan, false) or coalesce(p_can_edit, false)) then
    raise exception 'needs_permission' using errcode = 'P0001';
  end if;
  -- Serialise invitations of one organizer so the limit holds.
  perform 1 from public.profiles where id = v_me.id for update;
  if (select count(*) from public.team_members where organizer_id = v_me.id) >= 15 then
    raise exception 'team_full' using errcode = 'P0001';
  end if;

  select u.id into v_target_id
    from auth.users u
   where lower(u.email::text) = lower(btrim(coalesce(p_email, '')))
     and u.email_confirmed_at is not null;
  if v_target_id = v_me.id then
    raise exception 'cannot_invite_self' using errcode = 'P0001';
  end if;
  if v_target_id is null then
    return;
  end if;
  if exists (select 1 from public.team_members where organizer_id = v_me.id and member_id = v_target_id) then
    raise exception 'already_in_team' using errcode = 'P0001';
  end if;
  select * into v_target from public.profiles where id = v_target_id;
  if v_target.id is null then
    return;
  end if;
  if v_me.role in ('organizer', 'tenant_admin') and v_target.tenant_id is distinct from v_me.tenant_id then
    return;
  end if;

  insert into public.team_members (organizer_id, member_id, can_scan, can_edit)
  values (v_me.id, v_target_id, coalesce(p_can_scan, false), coalesce(p_can_edit, false));
  -- event_title carries the inviting organizer's name for the message text.
  insert into public.notifications (user_id, kind, event_title)
  values (v_target_id, 'team_invite', left(v_me.display_name, 200));
end $$;

revoke all on function public.team_invite(text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.team_invite(text, boolean, boolean) to authenticated;

-- The invited person accepts or declines.
create function public.team_respond(p_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_accept then
    update public.team_members set status = 'active', accepted_at = now()
     where id = p_id and member_id = auth.uid() and status = 'invited';
  else
    delete from public.team_members
     where id = p_id and member_id = auth.uid() and status = 'invited';
  end if;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.team_respond(uuid, boolean) from public, anon, authenticated;
grant execute on function public.team_respond(uuid, boolean) to authenticated;

-- The organizer changes what a teammate may do.
create function public.team_set_permissions(p_id uuid, p_can_scan boolean, p_can_edit boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (coalesce(p_can_scan, false) or coalesce(p_can_edit, false)) then
    raise exception 'needs_permission' using errcode = 'P0001';
  end if;
  update public.team_members
     set can_scan = coalesce(p_can_scan, false), can_edit = coalesce(p_can_edit, false)
   where id = p_id and organizer_id = auth.uid();
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.team_set_permissions(uuid, boolean, boolean) from public, anon, authenticated;
grant execute on function public.team_set_permissions(uuid, boolean, boolean) to authenticated;

-- The organizer removes a teammate (or withdraws an invitation), or the
-- teammate leaves.
create function public.team_remove(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.team_members
   where id = p_id and auth.uid() in (organizer_id, member_id);
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.team_remove(uuid) from public, anon, authenticated;
grant execute on function public.team_remove(uuid) to authenticated;

-- The organizer's own team.
create function public.team_my_members()
returns table (id uuid, member_id uuid, name text, email text, can_scan boolean, can_edit boolean,
               status text, invited_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.member_id, p.display_name, u.email::text, t.can_scan, t.can_edit, t.status, t.invited_at
    from public.team_members t
    join public.profiles p on p.id = t.member_id
    join auth.users u on u.id = t.member_id
   where t.organizer_id = auth.uid()
   order by t.status, p.display_name
$$;

revoke all on function public.team_my_members() from public, anon, authenticated;
grant execute on function public.team_my_members() to authenticated;

-- The teams the signed-in user was invited to or is part of.
-- usable: false while the team is frozen (see the rules at the top).
create function public.team_my_memberships()
returns table (id uuid, organizer_id uuid, organizer_name text, can_scan boolean, can_edit boolean,
               status text, usable boolean, organizer_tenant uuid, organizer_role public.user_role)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.organizer_id, o.display_name, t.can_scan, t.can_edit, t.status,
         t.status = 'active' and public.team_can(t.organizer_id, 'any'), o.tenant_id, o.role
    from public.team_members t
    join public.profiles o on o.id = t.organizer_id
   where t.member_id = auth.uid()
   order by t.status desc, o.display_name
$$;

revoke all on function public.team_my_memberships() from public, anon, authenticated;
grant execute on function public.team_my_memberships() to authenticated;

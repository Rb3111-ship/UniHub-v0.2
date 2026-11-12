-- 1. University roles only for accounts with a (confirmed) university e-mail.
-- 2. Case files: a lasting record of why an event or a user was removed, with the
--    reports as evidence. Before this, removing a user deleted their events and,
--    with them, every report about them.

-- ---------------------------------------------------------------------------
-- 1. "University organizer" and "university admin" need a university.
--    An account without one (for example a Gmail address) belongs to no
--    university, so such a role would be meaningless or, worse, a mistake.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_role(p_user uuid, p_role public.user_role, p_verified boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  select * into v_target from public.profiles where id = p_user;
  if v_me.id is null or v_target.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  if v_me.role = 'platform_admin' then
    null;
  elsif v_me.role = 'tenant_admin'
        and v_me.tenant_id is not null
        and v_target.tenant_id is not distinct from v_me.tenant_id
        and v_target.role in ('student', 'organizer')
        and p_role in ('student', 'organizer') then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_role in ('organizer', 'tenant_admin') and v_target.tenant_id is null then
    raise exception 'needs_university_email' using errcode = 'P0001';
  end if;

  if v_target.role = 'platform_admin' and p_role <> 'platform_admin' then
    -- Lock the admin rows so two admins demoting each other at the same moment
    -- cannot both get through.
    perform 1 from public.profiles where role = 'platform_admin' for update;
    if not exists (select 1 from public.profiles where role = 'platform_admin' and id <> p_user) then
      raise exception 'last_admin' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles set role = p_role, organizer_verified = p_verified where id = p_user;
end $$;

create or replace function public.review_organizer_request(p_request uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_req public.organizer_requests%rowtype;
  v_target_tenant uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  select * into v_req from public.organizer_requests where id = p_request for update;
  if v_me.id is null or v_req.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'already_reviewed' using errcode = 'P0001';
  end if;

  v_target_tenant := public.user_tenant(v_req.user_id);
  if v_me.role = 'platform_admin' then
    null;
  elsif v_me.role = 'tenant_admin' and v_req.requested_role = 'organizer'
        and v_me.tenant_id is not null and v_target_tenant is not distinct from v_me.tenant_id then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  -- The applicant may have left the university address since applying.
  if p_approve and v_req.requested_role = 'organizer' and v_target_tenant is null then
    raise exception 'needs_university_email' using errcode = 'P0001';
  end if;

  if p_approve then
    -- Only ever upgrade students; never downgrade or overwrite an admin.
    update public.profiles
       set role = v_req.requested_role, organizer_verified = true
     where id = v_req.user_id and role = 'student';
  end if;

  update public.organizer_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.organizer_request_status,
         reviewed_by = v_me.id, reviewed_at = now(), review_note = nullif(btrim(p_note), '')
   where id = p_request;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Case files.
--    Plain copies (no links to other tables), so they survive when the event
--    or the account is deleted. Who reported is NOT stored: only what was
--    reported and when. Kept for 12 months, then deleted automatically.
-- ---------------------------------------------------------------------------
create table public.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  action text not null check (action in ('event_removed', 'user_removed')),
  tenant_id uuid,                 -- whose university admin may read it (null: platform admins only)
  subject_user_id uuid,           -- the organizer / removed user (no link: the account may be gone)
  subject_name text not null default '',
  subject_email text not null default '',
  event_title text,               -- for 'event_removed'
  note text,                      -- what the admin wrote
  email_blocked boolean not null default false,
  decided_by uuid,
  decided_by_name text not null default '',
  report_count integer not null default 0,
  evidence jsonb not null default '[]'::jsonb   -- [{event_title, reason, details, reported_at, outcome}]
);

create index moderation_cases_created_idx on public.moderation_cases (created_at desc);

alter table public.moderation_cases enable row level security;
-- No policies and no grants: only the functions below read or write it.
revoke all on table public.moderation_cases from public, anon, authenticated;

-- The reports about one user's events, as evidence.
create function public.reports_as_evidence(p_organizer uuid, p_event uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'event_title', e.title,
           'reason', r.reason,
           'details', r.details,
           'reported_at', r.created_at,
           'outcome', r.status) order by r.created_at), '[]'::jsonb)
    from public.event_reports r
    join public.events e on e.id = r.event_id
   where e.organizer_id = p_organizer
     and (p_event is null or e.id = p_event)
$$;

revoke all on function public.reports_as_evidence(uuid, uuid) from public, anon, authenticated;

create or replace function public.resolve_report(p_report uuid, p_remove boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rep public.event_reports%rowtype;
  v_event public.events%rowtype;
  v_evidence jsonb;
begin
  select * into v_rep from public.event_reports where id = p_report for update;
  if v_rep.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if not public.can_moderate_event(v_rep.event_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if v_rep.status <> 'open' then
    raise exception 'already_reviewed' using errcode = 'P0001';
  end if;

  if p_remove then
    update public.events
       set status = 'cancelled', moderated_at = now(),
           moderation_note = nullif(btrim(left(coalesce(p_note, ''), 500)), '')
     where id = v_rep.event_id and status <> 'cancelled';
    update public.event_reports
       set status = 'removed', reviewed_by = auth.uid(), reviewed_at = now()
     where event_id = v_rep.event_id and status = 'open';

    -- Keep a case file with the reports that led to this.
    select * into v_event from public.events where id = v_rep.event_id;
    v_evidence := public.reports_as_evidence(v_event.organizer_id, v_event.id);
    insert into public.moderation_cases (action, tenant_id, subject_user_id, subject_name, subject_email,
                                         event_title, note, decided_by, decided_by_name, report_count, evidence)
    values ('event_removed', v_event.tenant_id, v_event.organizer_id,
            coalesce((select display_name from public.profiles where id = v_event.organizer_id), ''),
            coalesce((select email::text from auth.users where id = v_event.organizer_id), ''),
            v_event.title, nullif(btrim(left(coalesce(p_note, ''), 500)), ''),
            auth.uid(), coalesce((select display_name from public.profiles where id = auth.uid()), ''),
            jsonb_array_length(v_evidence), v_evidence);
  else
    update public.event_reports
       set status = 'dismissed', reviewed_by = auth.uid(), reviewed_at = now()
     where id = p_report;
  end if;
end $$;

create or replace function public.admin_delete_user(p_user uuid, p_block boolean default false)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_email text;
  v_events integer;
  v_evidence jsonb;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select * into v_target from public.profiles where id = p_user;
  select email into v_email from auth.users where id = p_user;
  if v_target.id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_user = v_me.id then
    raise exception 'cannot_remove_self' using errcode = 'P0001';
  end if;
  if v_target.role in ('platform_admin', 'tenant_admin') then
    raise exception 'demote_first' using errcode = 'P0001';
  end if;
  if v_me.role = 'tenant_admin'
     and not (v_me.tenant_id is not null
              and v_target.tenant_id is not distinct from v_me.tenant_id
              and v_target.role in ('student', 'organizer')) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  -- Case file first: the events (and with them the reports) are deleted below.
  v_evidence := public.reports_as_evidence(p_user);
  insert into public.moderation_cases (action, tenant_id, subject_user_id, subject_name, subject_email,
                                       email_blocked, decided_by, decided_by_name, report_count, evidence)
  values ('user_removed', v_target.tenant_id, p_user, v_target.display_name, coalesce(v_email, ''),
          p_block and v_email is not null, v_me.id, v_me.display_name,
          jsonb_array_length(v_evidence), v_evidence);

  -- The event rows are deleted below, so the message keeps only the title.
  insert into public.notifications (user_id, kind, event_title)
  select distinct r.user_id, 'event_cancelled', left(e.title, 200)
    from public.events e
    join public.registrations r on r.event_id = e.id
    join public.profiles p on p.id = r.user_id
   where e.organizer_id = p_user
     and e.status = 'published'
     and e.ends_at > now()
     and r.status in ('registered', 'waitlisted')
     and r.user_id <> p_user
     and p.notify_updates;

  delete from public.events where organizer_id = p_user;
  get diagnostics v_events = row_count;

  if p_block and v_email is not null then
    insert into public.blocked_emails (email, blocked_by, tenant_id)
    values (lower(v_email), v_me.id, case when v_me.role = 'tenant_admin' then v_me.tenant_id end)
    on conflict (email) do nothing;
  end if;

  -- Cascades remove the profile, registrations, tickets, reviews, favourites and requests.
  -- Uploaded files are removed by the Edge Function "remove-user" that calls this.
  delete from auth.users where id = p_user;
  return v_events;
end $$;

-- Admins read the case files through this (university admins: their university only).
create function public.admin_list_cases(p_limit integer default 100)
returns table (id uuid, created_at timestamptz, action text, subject_name text, subject_email text,
               event_title text, note text, email_blocked boolean, decided_by_name text,
               report_count integer, evidence jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles p where p.id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return query
    select c.id, c.created_at, c.action, c.subject_name, c.subject_email, c.event_title, c.note,
           c.email_blocked, c.decided_by_name, c.report_count, c.evidence
      from public.moderation_cases c
     where v_me.role = 'platform_admin'
        or (v_me.tenant_id is not null and c.tenant_id = v_me.tenant_id)
     order by c.created_at desc
     limit least(greatest(coalesce(p_limit, 100), 1), 200);
end $$;

revoke all on function public.admin_list_cases(integer) from public, anon, authenticated;
grant execute on function public.admin_list_cases(integer) to authenticated;

select cron.schedule('unihub-cases-cleanup', '40 3 * * *',
  $job$delete from public.moderation_cases where created_at < now() - interval '12 months'$job$);

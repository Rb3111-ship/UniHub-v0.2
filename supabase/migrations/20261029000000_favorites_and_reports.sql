-- Favourites (saved events) and reporting/moderation of events.

-- ---------------------------------------------------------------------------
-- 1. Favourites: private to each user
-- ---------------------------------------------------------------------------
create table public.favorites (
  user_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  event_id   uuid not null references public.events (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, event_id)
);
create index favorites_event_idx on public.favorites (event_id);
alter table public.favorites enable row level security;

create policy favorites_read on public.favorites for select to authenticated
  using (user_id = auth.uid());
-- Only events the user can see (the subquery runs with the user's own event rules),
-- and at most 500 saved events per person.
create policy favorites_insert on public.favorites for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.events e where e.id = event_id)
    and (select count(*) from public.favorites f where f.user_id = auth.uid()) < 500
  );
create policy favorites_delete on public.favorites for delete to authenticated
  using (user_id = auth.uid());

revoke all on public.favorites from anon, authenticated;
grant select, insert, delete on public.favorites to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Moderation fields on events (set only by admins through resolve_report)
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists moderated_at    timestamptz,
  add column if not exists moderation_note text check (moderation_note is null or char_length(moderation_note) <= 500);

-- Organizers insert events directly, so make sure they cannot fake a moderation mark.
create function public.events_clear_moderation() returns trigger
language plpgsql set search_path = public as $$
begin
  new.moderated_at := null;
  new.moderation_note := null;
  return new;
end $$;
revoke all on function public.events_clear_moderation() from public, anon, authenticated;
create trigger events_clear_moderation before insert on public.events
  for each row execute function public.events_clear_moderation();

-- ---------------------------------------------------------------------------
-- 3. Reports
-- ---------------------------------------------------------------------------
create table public.event_reports (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason      text not null check (reason in ('spam', 'inappropriate', 'misleading', 'scam', 'other')),
  details     text not null default '' check (char_length(details) <= 500),
  status      text not null default 'open' check (status in ('open', 'dismissed', 'removed')),
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at  timestamptz not null default now()
);
create unique index event_reports_one_open on public.event_reports (event_id, reporter_id) where status = 'open';
create index event_reports_status_idx on public.event_reports (status, created_at);
create index event_reports_reporter_idx on public.event_reports (reporter_id, created_at);
alter table public.event_reports enable row level security;

-- Who may act on reports about an event: platform admins, and university admins
-- for events of their own university.
create function public.can_moderate_event(p_event uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.events e join public.profiles me on me.id = auth.uid()
    where e.id = p_event
      and (me.role = 'platform_admin'
           or (me.role = 'tenant_admin' and e.tenant_id is not null and e.tenant_id = me.tenant_id))
  )
$$;

create policy event_reports_read on public.event_reports for select to authenticated
  using (reporter_id = auth.uid() or public.can_moderate_event(event_id));

revoke all on public.event_reports from anon, authenticated;
grant select on public.event_reports to authenticated;

create function public.report_event(p_event uuid, p_reason text, p_details text default '')
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_event public.events%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select * into v_event from public.events where id = p_event;
  -- Same visibility as the feed: you can only report what you can see.
  if not found or v_event.status <> 'published'
     or (v_event.tenant_id is not null and v_event.tenant_id is distinct from public.auth_tenant()) then
    raise exception 'event_not_available' using errcode = 'P0002';
  end if;
  if v_event.organizer_id = v_uid then
    raise exception 'own_event' using errcode = 'P0001';
  end if;
  if (select count(*) from public.event_reports
      where reporter_id = v_uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'too_many_reports' using errcode = 'P0001';
  end if;
  begin
    insert into public.event_reports (event_id, reporter_id, reason, details)
    values (p_event, v_uid, p_reason, btrim(coalesce(p_details, '')));
  exception when unique_violation then
    raise exception 'already_reported' using errcode = 'P0001';
  end;
end $$;

-- Dismiss one report, or remove the event: it is cancelled (tickets stop working),
-- marked as moderated, and every open report about it is closed.
create function public.resolve_report(p_report uuid, p_remove boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_rep public.event_reports%rowtype;
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
  else
    update public.event_reports
       set status = 'dismissed', reviewed_by = auth.uid(), reviewed_at = now()
     where id = p_report;
  end if;
end $$;

revoke all on function public.can_moderate_event(uuid), public.report_event(uuid, text, text),
  public.resolve_report(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.can_moderate_event(uuid) to authenticated;  -- used inside the RLS policy
grant execute on function public.report_event(uuid, text, text) to authenticated;
grant execute on function public.resolve_report(uuid, boolean, text) to authenticated;

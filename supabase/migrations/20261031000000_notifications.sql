-- Notifications: an in-app inbox plus push messages to phones and browsers.
--
-- Flow: something happens (event cancelled, time changed, waitlist spot, reminder,
-- application decided) -> a trigger writes a row into public.notifications ->
-- pg_net pokes the Edge Function "send-push" -> the function claims pending rows
-- and sends them through Firebase Cloud Messaging. A cron job retries anything
-- that did not go out. The inbox works even when push is not set up.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- 1. Preferences (account notices such as an application result are always sent).
alter table public.profiles
  add column if not exists notify_reminders boolean not null default true,
  add column if not exists notify_updates   boolean not null default true;
grant update (notify_reminders, notify_updates) on public.profiles to authenticated;

-- 2. Devices that can receive push messages. Written only through the functions below.
create table public.push_tokens (
  token      text primary key check (char_length(token) between 20 and 4096 and token !~ '\s'),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  platform   text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index push_tokens_user on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
-- No policies and no grants: only the definer functions and the server touch it.

create function public.register_push_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  -- A device belongs to whoever signed in on it last.
  insert into public.push_tokens (token, user_id, platform)
  values (p_token, v_uid, p_platform)
  on conflict (token) do update set user_id = v_uid, platform = excluded.platform, updated_at = now();
  -- At most 10 devices per account; the oldest are forgotten.
  delete from public.push_tokens
   where user_id = v_uid
     and token not in (select token from public.push_tokens where user_id = v_uid
                        order by updated_at desc limit 10);
end $$;

create function public.unregister_push_token(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.push_tokens where token = p_token and user_id = auth.uid();
$$;

-- 3. The inbox.
create table public.notifications (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  kind            text not null check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                                                'request_approved', 'request_rejected', 'event_removed')),
  event_id        uuid references public.events(id) on delete cascade,
  event_title     text check (char_length(event_title) <= 200),
  created_at      timestamptz not null default now(),
  read_at         timestamptz,
  push_state      text not null default 'pending' check (push_state in ('pending', 'sending', 'sent', 'skipped', 'failed')),
  push_attempts   smallint not null default 0,
  push_claimed_at timestamptz
);
create index notifications_user on public.notifications (user_id, created_at desc);
create index notifications_pending on public.notifications (id) where push_state in ('pending', 'sending');
create unique index notifications_one_reminder on public.notifications (user_id, event_id) where kind = 'reminder';

alter table public.notifications enable row level security;
create policy notifications_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated using (user_id = auth.uid());
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

-- 4. Writing notifications. p_pref: 'updates' or 'reminders' (null = always).
create function public.notify_event_attendees(p_event uuid, p_kind text, p_pref text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, event_id, event_title)
  select r.user_id, p_kind, e.id, left(e.title, 200)
    from public.registrations r
    join public.events e on e.id = r.event_id
    join public.profiles p on p.id = r.user_id
   where r.event_id = p_event
     and r.status in ('registered', 'waitlisted')
     and r.user_id is distinct from e.organizer_id
     and case p_pref when 'updates' then p.notify_updates when 'reminders' then p.notify_reminders else true end
     -- Several quick edits in a row produce one message, not one per save.
     and not exists (select 1 from public.notifications n
                      where n.user_id = r.user_id and n.event_id = e.id and n.kind = p_kind
                        and n.created_at > now() - interval '10 minutes');
end $$;

create function public.events_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    perform public.notify_event_attendees(new.id, 'event_cancelled', 'updates');
    if new.moderated_at is not null and old.moderated_at is null and new.organizer_id is not null then
      insert into public.notifications (user_id, kind, event_id, event_title)
      values (new.organizer_id, 'event_removed', new.id, left(new.title, 200));
    end if;
  elsif new.status = 'published' and old.status = 'published'
        and (new.starts_at is distinct from old.starts_at or new.location is distinct from old.location) then
    perform public.notify_event_attendees(new.id, 'event_changed', 'updates');
  end if;
  return null;
end $$;
create trigger events_notify after update on public.events
  for each row execute function public.events_notify();

create function public.registrations_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'waitlisted' and new.status = 'registered' then
    insert into public.notifications (user_id, kind, event_id, event_title)
    select new.user_id, 'waitlist_promoted', e.id, left(e.title, 200)
      from public.events e join public.profiles p on p.id = new.user_id
     where e.id = new.event_id and p.notify_updates;
  end if;
  return null;
end $$;
create trigger registrations_notify after update of status on public.registrations
  for each row execute function public.registrations_notify();

create function public.organizer_requests_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'pending' and new.status in ('approved', 'rejected') then
    insert into public.notifications (user_id, kind)
    values (new.user_id, case when new.status = 'approved' then 'request_approved' else 'request_rejected' end);
  end if;
  return null;
end $$;
create trigger organizer_requests_notify after update of status on public.organizer_requests
  for each row execute function public.organizer_requests_notify();

-- Reminders for registered users, once per event, in the 24 hours before it starts
-- (not for events less than 30 minutes away, nor right after registering).
create function public.queue_event_reminders() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  insert into public.notifications (user_id, kind, event_id, event_title)
  select r.user_id, 'reminder', e.id, left(e.title, 200)
    from public.registrations r
    join public.events e on e.id = r.event_id
    join public.profiles p on p.id = r.user_id
   where r.status = 'registered' and e.status = 'published'
     and e.starts_at > now() + interval '30 minutes' and e.starts_at <= now() + interval '24 hours'
     and r.created_at < now() - interval '1 hour'
     and p.notify_reminders
  on conflict do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- 5. Delivery. The function address and a shared secret live in Vault, so the
--    Edge Function only works when called by this database. They are created
--    once by hand with supabase/setup/push_secrets.sql; until then nothing is sent.

create function public.kick_push() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_hook_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret),
    timeout_milliseconds := 10000);
end $$;

create function public.notifications_kick() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.kick_push();
  return null;
end $$;
create trigger notifications_kick after insert on public.notifications
  for each statement execute function public.notifications_kick();

create function public.retry_push() returns void
language plpgsql security definer set search_path = '' as $$
begin
  -- Messages that never went out within two days, or failed five times, are given up.
  update public.notifications set push_state = 'failed'
   where push_state in ('pending', 'sending')
     and (created_at < now() - interval '2 days' or push_attempts >= 5);
  if exists (select 1 from public.notifications where push_state = 'pending'
              or (push_state = 'sending' and push_claimed_at < now() - interval '5 minutes')) then
    perform public.kick_push();
  end if;
end $$;

-- Used only by the Edge Function (service role).
create function public.push_secret_ok(p_secret text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from vault.decrypted_secrets where name = 'push_hook_secret' and decrypted_secret = p_secret);
$$;

create function public.claim_push_batch(p_limit integer default 200)
returns table (id bigint, user_id uuid, kind text, event_id uuid, event_title text, starts_at timestamptz)
language sql security definer set search_path = '' as $$
  with c as (
    select n.id from public.notifications n
     where (n.push_state = 'pending' or (n.push_state = 'sending' and n.push_claimed_at < now() - interval '5 minutes'))
       and n.push_attempts < 5 and n.created_at > now() - interval '2 days'
     order by n.id
     limit least(greatest(p_limit, 1), 500)
     for update skip locked)
  update public.notifications n
     set push_state = 'sending', push_claimed_at = now(), push_attempts = n.push_attempts + 1
    from c
   where n.id = c.id
  returning n.id, n.user_id, n.kind, n.event_id, n.event_title,
            (select e.starts_at from public.events e where e.id = n.event_id);
$$;

create function public.finish_push(p_ids bigint[], p_state text) returns void
language sql security definer set search_path = '' as $$
  update public.notifications set push_state = p_state
   where id = any(p_ids) and push_state = 'sending' and p_state in ('sent', 'skipped', 'failed', 'pending');
$$;

create function public.push_targets(p_users uuid[])
returns table (user_id uuid, token text, platform text, locale text)
language sql stable security definer set search_path = '' as $$
  select t.user_id, t.token, t.platform, p.locale
    from public.push_tokens t join public.profiles p on p.id = t.user_id
   where t.user_id = any(p_users);
$$;

create function public.forget_push_tokens(p_tokens text[]) returns void
language sql security definer set search_path = '' as $$
  delete from public.push_tokens where token = any(p_tokens);
$$;

-- 6. Who may call what. Everything internal is server-only.
revoke all on function public.register_push_token(text, text), public.unregister_push_token(text),
  public.notify_event_attendees(uuid, text, text), public.events_notify(), public.registrations_notify(),
  public.organizer_requests_notify(), public.queue_event_reminders(), public.kick_push(), public.notifications_kick(),
  public.retry_push(), public.push_secret_ok(text), public.claim_push_batch(integer), public.finish_push(bigint[], text),
  public.push_targets(uuid[]), public.forget_push_tokens(text[])
  from public, anon, authenticated;
grant execute on function public.register_push_token(text, text), public.unregister_push_token(text) to authenticated;
grant execute on function public.push_secret_ok(text), public.claim_push_batch(integer), public.finish_push(bigint[], text),
  public.push_targets(uuid[]), public.forget_push_tokens(text[]) to service_role;

-- 7. Scheduled jobs.
select cron.schedule('unihub-reminders', '*/10 * * * *', 'select public.queue_event_reminders()');
select cron.schedule('unihub-push-retry', '*/5 * * * *', 'select public.retry_push()');
select cron.schedule('unihub-notifications-cleanup', '30 3 * * *',
  $$delete from public.notifications where created_at < now() - interval '90 days'$$);

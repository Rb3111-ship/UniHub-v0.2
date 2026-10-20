-- UniHub initial schema (v0.2)
--
-- Design rules:
--   * Every table has Row Level Security (RLS) enabled. Clients talk to the database
--     directly through the Supabase API, so RLS is the security boundary.
--   * Anything that must be atomic or trusted (registering, cancelling, check-in,
--     reviews) is a SECURITY DEFINER function. Clients get no direct write access to
--     registrations, tickets, scan_log or reviews.
--   * Tenant (university) membership is derived from a CONFIRMED e-mail domain by a
--     trigger. Users can never edit their own role, tenant or verified flag.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum
  ('student', 'organizer', 'commercial_planner', 'tenant_admin', 'platform_admin');
create type public.event_status as enum ('draft', 'published', 'cancelled');
create type public.registration_status as enum ('registered', 'waitlisted', 'cancelled');
create type public.scan_result as enum
  ('granted', 'already_used', 'invalid', 'wrong_event', 'cancelled');

-- ---------------------------------------------------------------------------
-- Tenants (universities)
-- ---------------------------------------------------------------------------
create table public.tenants (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name_en     text not null,
  name_de     text not null,
  brand_color text not null default '#6B7280' check (brand_color ~ '^#[0-9A-Fa-f]{6}$'),
  logo_path   text,
  created_at  timestamptz not null default now()
);

-- E-mail domains that grant membership, e.g. tum.de (also matches mail.tum.de).
create table public.tenant_domains (
  domain    text primary key check (domain = lower(domain)),
  tenant_id uuid not null references public.tenants (id) on delete cascade
);
create index tenant_domains_tenant_idx on public.tenant_domains (tenant_id);

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  tenant_id          uuid references public.tenants (id) on delete set null,
  display_name       text not null default '' check (char_length(display_name) <= 80),
  role               public.user_role not null default 'student',
  -- Organizers and commercial planners must be approved by an admin before publishing.
  organizer_verified boolean not null default false,
  locale             text not null default 'en' check (locale in ('en', 'de')),
  avatar_path        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index profiles_tenant_idx on public.profiles (tenant_id);

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
create table public.events (
  id           uuid primary key default gen_random_uuid(),
  -- NULL tenant_id = public event (visible to everyone). Otherwise official, visible
  -- to members of that tenant only.
  tenant_id    uuid references public.tenants (id) on delete restrict,
  organizer_id uuid not null references public.profiles (id) on delete restrict,
  title        text not null check (char_length(btrim(title)) between 3 and 140),
  description  text not null default '' check (char_length(description) <= 5000),
  location     text not null check (char_length(btrim(location)) between 2 and 200),
  starts_at    timestamptz not null,
  ends_at      timestamptz not null,
  capacity     integer check (capacity is null or capacity > 0),  -- NULL = unlimited
  price_cents  integer not null default 0 check (price_cents >= 0),
  currency     text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  requires_qr  boolean not null default true,
  allow_reviews boolean not null default true,
  categories   text[] not null default array['Other']
               check (cardinality(categories) between 1 and 3),
  image_path   text,
  status       public.event_status not null default 'draft',
  is_official  boolean generated always as (tenant_id is not null) stored,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index events_tenant_start_idx on public.events (tenant_id, starts_at);
create index events_organizer_idx on public.events (organizer_id);
create index events_public_feed_idx on public.events (starts_at) where status = 'published';
create index events_categories_idx on public.events using gin (categories);

-- ---------------------------------------------------------------------------
-- Registrations, tickets, scan log, reviews
-- ---------------------------------------------------------------------------
create table public.registrations (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  status       public.registration_status not null,
  created_at   timestamptz not null default now(),
  cancelled_at timestamptz,
  unique (event_id, user_id)
);
create index registrations_user_idx on public.registrations (user_id);
create index registrations_event_status_idx on public.registrations (event_id, status, created_at);

create table public.tickets (
  id              uuid primary key default gen_random_uuid(),
  registration_id uuid not null unique references public.registrations (id) on delete cascade,
  event_id        uuid not null references public.events (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  ticket_number   bigint generated always as identity,
  -- Secret value encoded in the QR code. 256 bits of randomness, replaced on re-issue.
  code            text not null unique
                  default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  issued_at       timestamptz not null default now(),
  voided_at       timestamptz,
  checked_in_at   timestamptz,
  checked_in_by   uuid references public.profiles (id) on delete set null
);
create index tickets_user_idx on public.tickets (user_id);
create index tickets_event_idx on public.tickets (event_id);

create table public.scan_log (
  id         bigint generated always as identity primary key,
  event_id   uuid not null references public.events (id) on delete cascade,
  ticket_id  uuid references public.tickets (id) on delete set null,
  scanned_by uuid references public.profiles (id) on delete set null,
  result     public.scan_result not null,
  scanned_at timestamptz not null default now()
);
create index scan_log_event_idx on public.scan_log (event_id, scanned_at desc);

create table public.reviews (
  id                 uuid primary key default gen_random_uuid(),
  event_id           uuid not null references public.events (id) on delete cascade,
  ticket_id          uuid not null unique references public.tickets (id) on delete cascade,  -- one review per ticket
  user_id            uuid not null references public.profiles (id) on delete cascade,
  rating             smallint not null check (rating between 1 and 5),
  comment            text not null check (char_length(btrim(comment)) between 1 and 2000),
  claimed_attendance boolean not null default false,
  -- Set by the server from the ticket's scan record, never by the client.
  is_verified        boolean not null,
  created_at         timestamptz not null default now()
);
create index reviews_event_idx on public.reviews (event_id);

-- ---------------------------------------------------------------------------
-- Generic triggers
-- ---------------------------------------------------------------------------
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger events_touch before update on public.events
  for each row execute function public.touch_updated_at();

-- Ownership and tenant of an event never change after creation.
create function public.events_lock_identity() returns trigger
language plpgsql as $$
begin
  if new.organizer_id is distinct from old.organizer_id
     or new.tenant_id is distinct from old.tenant_id then
    raise exception 'organizer_and_tenant_are_immutable' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger events_lock_identity before update on public.events
  for each row execute function public.events_lock_identity();

-- ---------------------------------------------------------------------------
-- Auth helpers (SECURITY DEFINER so RLS policies can use them without recursion)
-- ---------------------------------------------------------------------------
create function public.auth_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create function public.auth_tenant() returns uuid
language sql stable security definer set search_path = public as $$
  select tenant_id from public.profiles where id = auth.uid()
$$;

create function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'platform_admin' from public.profiles where id = auth.uid()), false)
$$;

-- Verified organizer / commercial planner allowed to publish events.
create function public.can_publish_for(p_tenant uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.organizer_verified
      and (
        (p_tenant is null and p.role = 'commercial_planner')
        or (p_tenant is not null and p.tenant_id = p_tenant and p.role in ('organizer', 'tenant_admin'))
        or p.role = 'platform_admin'
      )
  )
$$;

-- Owner of the event, admin of its tenant, or platform admin.
create function public.can_manage_event(p_event uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.events e
    join public.profiles me on me.id = auth.uid()
    where e.id = p_event
      and (
        e.organizer_id = me.id
        or (me.role = 'tenant_admin' and e.tenant_id is not null and e.tenant_id = me.tenant_id)
        or me.role = 'platform_admin'
      )
  )
$$;

-- ---------------------------------------------------------------------------
-- New user -> profile, tenant from confirmed e-mail domain
-- ---------------------------------------------------------------------------
create function public.assign_tenant_from_email(p_user uuid, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_domain text := lower(split_part(p_email, '@', 2));
  v_tenant uuid;
begin
  select td.tenant_id into v_tenant
  from public.tenant_domains td
  where v_domain = td.domain or v_domain like '%.' || td.domain
  order by length(td.domain) desc
  limit 1;

  if v_tenant is not null then
    update public.profiles set tenant_id = v_tenant where id = p_user and tenant_id is null;
  end if;
end $$;

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(new.email, ''), '@', 1)));

  -- Only trust the domain once the address is confirmed (OAuth users arrive confirmed).
  if new.email_confirmed_at is not null then
    perform public.assign_tenant_from_email(new.id, new.email);
  end if;
  return new;
end $$;

create function public.handle_user_confirmed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.assign_tenant_from_email(new.id, new.email);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
create trigger on_auth_user_confirmed after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.handle_user_confirmed();

-- ---------------------------------------------------------------------------
-- Ticketing functions (the only way to change registrations/tickets/reviews)
-- ---------------------------------------------------------------------------
create function public.issue_ticket(p_registration uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.tickets (registration_id, event_id, user_id)
  select r.id, r.event_id, r.user_id from public.registrations r where r.id = p_registration
  on conflict (registration_id) do update
    set code = replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
        voided_at = null,
        issued_at = now();
end $$;

-- Moves people from the waitlist into free seats, oldest first. Caller must hold the
-- event row lock.
create function public.promote_waitlist(p_event uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_capacity integer;
  v_taken integer;
  v_next uuid;
begin
  select capacity into v_capacity from public.events where id = p_event;
  loop
    select count(*) into v_taken
      from public.registrations where event_id = p_event and status = 'registered';
    exit when v_capacity is not null and v_taken >= v_capacity;

    select id into v_next from public.registrations
      where event_id = p_event and status = 'waitlisted'
      order by created_at limit 1;
    exit when v_next is null;

    update public.registrations set status = 'registered' where id = v_next;
    perform public.issue_ticket(v_next);
  end loop;
end $$;

-- If an organizer raises capacity, seat waitlisted people automatically.
create function public.events_capacity_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.promote_waitlist(new.id);
  return null;
end $$;
create trigger events_capacity_changed after update of capacity on public.events
  for each row when (old.capacity is distinct from new.capacity)
  execute function public.events_capacity_changed();

create function public.register_for_event(p_event_id uuid) returns public.registrations
language plpgsql security definer set search_path = public as $$
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

  select * into v_event from public.events where id = p_event_id for update;  -- serialises capacity checks
  if not found or v_event.status <> 'published'
     or (v_event.tenant_id is not null and v_event.tenant_id is distinct from public.auth_tenant()) then
    raise exception 'event_not_available' using errcode = 'P0002';
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

create function public.cancel_registration(p_event_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_reg public.registrations%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  perform 1 from public.events where id = p_event_id for update;  -- same lock order as register
  select * into v_reg from public.registrations where event_id = p_event_id and user_id = v_uid;
  if not found or v_reg.status = 'cancelled' then
    return;
  end if;
  if exists (select 1 from public.tickets where registration_id = v_reg.id and checked_in_at is not null) then
    raise exception 'already_checked_in' using errcode = 'P0001';
  end if;

  update public.registrations set status = 'cancelled', cancelled_at = now() where id = v_reg.id;
  update public.tickets set voided_at = now() where registration_id = v_reg.id;
  perform public.promote_waitlist(p_event_id);
end $$;

-- Door check-in. Returns {ok, result, attendee_name, ticket_number}.
create function public.check_in_ticket(p_code text, p_event_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.tickets%rowtype;
  v_event_status public.event_status;
  v_name text;
  v_updated integer;
begin
  if v_uid is null or not public.can_manage_event(p_event_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select status into v_event_status from public.events where id = p_event_id;
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

  if v_ticket.voided_at is not null or v_event_status = 'cancelled' then
    insert into public.scan_log (event_id, ticket_id, scanned_by, result)
      values (p_event_id, v_ticket.id, v_uid, 'cancelled');
    return jsonb_build_object('ok', false, 'result', 'cancelled');
  end if;

  -- Conditional update makes concurrent double-scans safe: only one wins.
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

create function public.submit_review(
  p_event_id uuid,
  p_rating integer,
  p_comment text,
  p_claimed_attendance boolean default false
) returns public.reviews
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_event public.events%rowtype;
  v_ticket public.tickets%rowtype;
  v_review public.reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_event from public.events where id = p_event_id;
  if not found or not v_event.allow_reviews then
    raise exception 'reviews_not_allowed' using errcode = 'P0001';
  end if;
  if v_event.starts_at > now() then
    raise exception 'event_not_started' using errcode = 'P0001';
  end if;

  select * into v_ticket from public.tickets
    where event_id = p_event_id and user_id = v_uid and voided_at is null;
  if not found then
    raise exception 'no_ticket' using errcode = 'P0001';
  end if;
  if v_event.requires_qr and v_ticket.checked_in_at is null then
    raise exception 'check_in_required' using errcode = 'P0001';
  end if;

  -- "Verified" means the door scan happened, regardless of the event's QR setting.
  insert into public.reviews (event_id, ticket_id, user_id, rating, comment, claimed_attendance, is_verified)
  values (p_event_id, v_ticket.id, v_uid, p_rating, p_comment,
          p_claimed_attendance or v_ticket.checked_in_at is not null,
          v_ticket.checked_in_at is not null)
  returning * into v_review;  -- unique(ticket_id) rejects a second review
  return v_review;
end $$;

-- Seats taken for a visible event (students cannot read other people's registrations).
create function public.event_registered_count(p_event_id uuid) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer
  from public.registrations r
  join public.events e on e.id = r.event_id
  where r.event_id = p_event_id
    and r.status = 'registered'
    and e.status = 'published'
    and (e.tenant_id is null or e.tenant_id = public.auth_tenant())
$$;

-- Role / verification changes go through here, never through direct profile updates.
-- Platform admins may set anything; tenant admins may approve organizers in their tenant.
create function public.admin_set_role(p_user uuid, p_role public.user_role, p_verified boolean)
returns void
language plpgsql security definer set search_path = public as $$
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
        and v_target.tenant_id is not distinct from v_me.tenant_id
        and v_me.tenant_id is not null
        and p_role in ('student', 'organizer') then
    null;
  else
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  update public.profiles set role = p_role, organizer_verified = p_verified where id = p_user;
end $$;

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------
-- Ratings shown to students: verified reviews only.
create view public.event_rating_stats with (security_invoker = true) as
select event_id,
       round(avg(rating)::numeric, 2) as average_rating,
       count(*)::integer as review_count
from public.reviews
where is_verified
group by event_id;

-- Planner dashboard numbers. Counts only rows the caller may see, i.e. their own events.
create view public.event_stats with (security_invoker = true) as
select e.id as event_id,
       e.title,
       e.capacity,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'registered')::integer as registered,
       (select count(*) from public.registrations r where r.event_id = e.id and r.status = 'waitlisted')::integer as waitlisted,
       (select count(*) from public.tickets t where t.event_id = e.id and t.checked_in_at is not null)::integer as checked_in
from public.events e
where public.can_manage_event(e.id);

-- Safe public info about people who publish events (names of verified organizers only).
create view public.organizer_profiles with (security_invoker = false) as
select id, display_name, tenant_id, role
from public.profiles
where organizer_verified and role in ('organizer', 'tenant_admin', 'commercial_planner');

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.tenants        enable row level security;
alter table public.tenant_domains enable row level security;
alter table public.profiles       enable row level security;
alter table public.events         enable row level security;
alter table public.registrations  enable row level security;
alter table public.tickets        enable row level security;
alter table public.scan_log       enable row level security;
alter table public.reviews        enable row level security;

-- tenants: readable by everyone (branding on the login screen); admin-managed.
create policy tenants_read on public.tenants for select to anon, authenticated using (true);
create policy tenants_admin on public.tenants for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy tenant_domains_admin on public.tenant_domains for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- profiles: own row, plus admins. Writes limited to harmless columns (see grants).
create policy profiles_read on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or public.is_platform_admin()
    or (public.auth_role() = 'tenant_admin' and tenant_id = public.auth_tenant())
  );
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- events
create policy events_read on public.events for select to anon, authenticated
  using (
    (status = 'published' and (tenant_id is null or tenant_id = public.auth_tenant()))
    or public.can_manage_event(id)
  );
create policy events_insert on public.events for insert to authenticated
  with check (organizer_id = auth.uid() and public.can_publish_for(tenant_id));
create policy events_update on public.events for update to authenticated
  using (public.can_manage_event(id)) with check (public.can_manage_event(id));
create policy events_delete on public.events for delete to authenticated
  using (public.can_manage_event(id) and status = 'draft');

-- registrations / tickets: attendee sees own; organizers see their event's.
create policy registrations_read on public.registrations for select to authenticated
  using (user_id = auth.uid() or public.can_manage_event(event_id));
create policy tickets_read on public.tickets for select to authenticated
  using (user_id = auth.uid() or public.can_manage_event(event_id));
create policy scan_log_read on public.scan_log for select to authenticated
  using (public.can_manage_event(event_id));

-- reviews: verified ones are public (if the event is visible); unverified only to the
-- author and the organizers.
create policy reviews_read on public.reviews for select to anon, authenticated
  using (
    user_id = auth.uid()
    or public.can_manage_event(event_id)
    or (is_verified and exists (select 1 from public.events e where e.id = reviews.event_id))
  );

-- ---------------------------------------------------------------------------
-- Privileges (defence in depth on top of RLS)
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.tenants, public.events, public.reviews,
                public.event_rating_stats, public.organizer_profiles to anon;
grant select on public.tenants, public.profiles, public.events, public.registrations,
                public.tickets, public.scan_log, public.reviews,
                public.event_rating_stats, public.event_stats, public.organizer_profiles
  to authenticated;
grant insert, update, delete on public.tenants, public.tenant_domains to authenticated;  -- RLS: platform admin
grant select on public.tenant_domains to authenticated;
grant insert, delete on public.events to authenticated;
grant update (title, description, location, starts_at, ends_at, capacity, price_cents,
              currency, requires_qr, allow_reviews, categories, image_path, status)
  on public.events to authenticated;
-- Users may edit only these profile columns; role/tenant/verified need an admin.
-- (Admins edit those through the dashboard / service role.)
grant update (display_name, locale, avatar_path) on public.profiles to authenticated;

-- RLS helper functions are called from policies, so they must be executable.
grant execute on function public.auth_role(), public.auth_tenant(), public.is_platform_admin(),
                          public.can_publish_for(uuid), public.can_manage_event(uuid)
  to anon, authenticated;
-- Client-callable ticketing API.
grant execute on function public.register_for_event(uuid), public.cancel_registration(uuid),
                          public.check_in_ticket(text, uuid),
                          public.submit_review(uuid, integer, text, boolean)
  to authenticated;
grant execute on function public.event_registered_count(uuid) to anon, authenticated;
grant execute on function public.admin_set_role(uuid, public.user_role, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: public event posters, writable by publishers inside their own folder
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-images', 'event-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy event_images_read on storage.objects for select
  using (bucket_id = 'event-images');
create policy event_images_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.auth_role() in ('organizer', 'tenant_admin', 'commercial_planner', 'platform_admin')
  );
create policy event_images_modify on storage.objects for update to authenticated
  using (bucket_id = 'event-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy event_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'event-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- Admins can see blocked addresses and unblock them.
-- Platform admins see every block; university admins see the blocks made by
-- admins of their own university.

alter table public.blocked_emails
  add column tenant_id uuid references public.tenants(id) on delete set null;

create or replace function public.admin_delete_user(p_user uuid, p_block boolean default false)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_me public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_email text;
  v_events integer;
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

create function public.admin_list_blocked_emails()
returns table(email text, created_at timestamptz, blocked_by_name text)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return query
    select b.email, b.created_at, p.display_name
      from public.blocked_emails b
      left join public.profiles p on p.id = b.blocked_by
     where v_me.role = 'platform_admin' or (v_me.tenant_id is not null and b.tenant_id = v_me.tenant_id)
     order by b.created_at desc
     limit 500;
end $$;

-- Returns true if a block was lifted.
create function public.admin_unblock_email(p_email text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_me public.profiles%rowtype;
  v_count integer;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role not in ('platform_admin', 'tenant_admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  delete from public.blocked_emails b
   where b.email = lower(btrim(p_email))
     and (v_me.role = 'platform_admin' or (v_me.tenant_id is not null and b.tenant_id = v_me.tenant_id));
  get diagnostics v_count = row_count;
  return v_count > 0;
end $$;

revoke all on function public.admin_list_blocked_emails(), public.admin_unblock_email(text) from public, anon, authenticated;
grant execute on function public.admin_list_blocked_emails(), public.admin_unblock_email(text) to authenticated;

-- 1. Organizers cannot register for their own events (it would take a seat and
--    skew the attendance numbers).
-- 2. Organizer applications carry what an admin needs to verify the person:
--    position, phone (required), website, and up to 3 documents in a PRIVATE bucket.

-- ---------------------------------------------------------------------------
-- 1. Own events
-- ---------------------------------------------------------------------------
create or replace function public.register_for_event(p_event_id uuid) returns public.registrations
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

-- ---------------------------------------------------------------------------
-- 2. Verification details on organizer requests
-- ---------------------------------------------------------------------------
alter table public.organizer_requests
  add column if not exists applicant_position text,
  add column if not exists phone              text,
  add column if not exists website_url        text,
  add column if not exists documents          text[] not null default '{}';

alter table public.organizer_requests add constraint organizer_requests_position_ok check (
  applicant_position is null or char_length(btrim(applicant_position)) between 2 and 120);
-- Same rules as the event contact fields.
alter table public.organizer_requests add constraint organizer_requests_phone_ok check (
  phone is null
  or (phone ~ '^\+?[0-9][0-9 ()/-]{4,28}[0-9]$'
      and char_length(regexp_replace(phone, '[^0-9]', '', 'g')) between 5 and 20));
alter table public.organizer_requests add constraint organizer_requests_website_ok check (
  website_url is null
  or (char_length(website_url) <= 500
      and website_url ~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]{1,5})?(/[^\s<>"]*)?$'));

-- Document paths: at most 3, each "<user id>/doc-<number>.<pdf|jpg|png>" in the applicant's folder.
create function public.organizer_docs_ok(p_user uuid, p_docs text[]) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(cardinality(p_docs), 0) <= 3
     and not exists (
       select 1 from unnest(coalesce(p_docs, '{}')) d
       where d is null
          or d !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/doc-[0-9]{1,20}\.(pdf|jpg|png)$'
          or split_part(d, '/', 1) <> p_user::text)
     and (select count(distinct d) from unnest(coalesce(p_docs, '{}')) d) = coalesce(cardinality(p_docs), 0)
$$;
revoke all on function public.organizer_docs_ok(uuid, text[]) from public, anon, authenticated;

alter table public.organizer_requests add constraint organizer_requests_documents_ok
  check (public.organizer_docs_ok(user_id, documents));

-- The old 3-argument version is replaced: a phone number is now required.
drop function public.request_organizer_access(public.user_role, text, text);

create function public.request_organizer_access(
  p_role public.user_role, p_org text, p_message text, p_position text, p_phone text,
  p_website text default null, p_documents text[] default '{}')
returns public.organizer_requests
language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles%rowtype;
  v_req public.organizer_requests%rowtype;
  v_docs text[] := coalesce(p_documents, '{}');
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_role not in ('organizer', 'commercial_planner') then
    raise exception 'invalid_role' using errcode = 'P0001';
  end if;
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.role <> 'student' then
    raise exception 'already_organizer' using errcode = 'P0001';
  end if;
  if p_role = 'organizer' and v_me.tenant_id is null then
    raise exception 'no_university' using errcode = 'P0001';
  end if;
  if nullif(btrim(p_phone), '') is null then
    raise exception 'phone_required' using errcode = 'P0001';
  end if;
  if nullif(btrim(p_position), '') is null then
    raise exception 'position_required' using errcode = 'P0001';
  end if;
  if not public.organizer_docs_ok(auth.uid(), v_docs) then
    raise exception 'invalid_documents' using errcode = 'P0001';
  end if;
  -- Every listed document must really have been uploaded by this user.
  if exists (
    select 1 from unnest(v_docs) d
    where not exists (select 1 from storage.objects o
                      where o.bucket_id = 'organizer-docs' and o.name = d and o.owner = auth.uid())
  ) then
    raise exception 'invalid_documents' using errcode = 'P0001';
  end if;
  begin
    insert into public.organizer_requests (user_id, email, requested_role, organization_name, message,
                                           applicant_position, phone, website_url, documents)
    values (auth.uid(), coalesce(auth.jwt() ->> 'email', ''), p_role, p_org, coalesce(p_message, ''),
            btrim(p_position), btrim(p_phone), nullif(btrim(p_website), ''), v_docs)
    returning * into v_req;
  exception when unique_violation then
    raise exception 'request_pending' using errcode = 'P0001';
  end;
  return v_req;
end $$;

revoke all on function public.request_organizer_access(public.user_role, text, text, text, text, text, text[])
  from public, anon, authenticated;
grant execute on function public.request_organizer_access(public.user_role, text, text, text, text, text, text[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Private bucket for the documents
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('organizer-docs', 'organizer-docs', false, 5242880, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Upload: students only, into their own folder, with the expected file name,
-- and at most 6 files at a time (so the bucket cannot be used as free storage).
-- Count the caller's documents without going through the storage policies
-- (counting inside the policy itself recursed).
create or replace function public.my_organizer_doc_count() returns integer
language sql stable security definer set search_path = public, storage as $$
  select count(*)::integer from storage.objects o
  where o.bucket_id = 'organizer-docs' and (storage.foldername(o.name))[1] = auth.uid()::text
$$;
revoke all on function public.my_organizer_doc_count() from public, anon, authenticated;
grant execute on function public.my_organizer_doc_count() to authenticated;  -- used inside the storage policy

create policy organizer_docs_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'organizer-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
    and name ~ '^[0-9a-f-]{36}/doc-[0-9]{1,20}\.(pdf|jpg|png)$'
    and public.auth_role() = 'student'
    and public.my_organizer_doc_count() < 6
  );

-- Read: the applicant, and whoever may see the request (platform admins, and
-- university admins for their own university). This reuses the request's own RLS.
create policy organizer_docs_read on storage.objects for select to authenticated
  using (
    bucket_id = 'organizer-docs'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or exists (select 1 from public.organizer_requests r where objects.name = any (r.documents)))
  );

-- Delete: the applicant at any time; a reviewer once the request has been decided
-- (the app removes the documents right after approving or rejecting).
create policy organizer_docs_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'organizer-docs'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or exists (select 1 from public.organizer_requests r
                    where objects.name = any (r.documents) and r.status <> 'pending'))
  );

-- Optional contact details and website on events, and organizer names for the feed.

-- 1. Contact fields. Checked here so no client can store scripts or odd links.
alter table public.events
  add column if not exists contact_email text,
  add column if not exists contact_phone text,
  add column if not exists website_url   text;

alter table public.events drop constraint if exists events_contact_email_ok;
alter table public.events add constraint events_contact_email_ok check (
  contact_email is null
  or (char_length(contact_email) <= 254
      and contact_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'));

alter table public.events drop constraint if exists events_contact_phone_ok;
alter table public.events add constraint events_contact_phone_ok check (
  contact_phone is null
  or (contact_phone ~ '^\+?[0-9][0-9 ()/-]{4,28}[0-9]$'
      and char_length(regexp_replace(contact_phone, '[^0-9]', '', 'g')) between 5 and 20));

-- Only https links: no javascript:, data: or plain-http pages.
alter table public.events drop constraint if exists events_website_ok;
alter table public.events add constraint events_website_ok check (
  website_url is null
  or (char_length(website_url) <= 500
      and website_url ~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]{1,5})?(/[^\s<>"]*)?$'));

grant update (contact_email, contact_phone, website_url) on public.events to authenticated;

-- 2. Organizer names shown to students: verified publishers, including platform
--    admins, plus the club/organization name from their approved request.
--    Still no e-mail address or other private data.
create or replace view public.organizer_profiles with (security_invoker = false) as
select p.id, p.display_name, p.tenant_id, p.role, p.avatar_path,
       (select r.organization_name
          from public.organizer_requests r
         where r.user_id = p.id and r.status = 'approved'
         order by r.reviewed_at desc nulls last
         limit 1) as organization_name
from public.profiles p
where p.organizer_verified
  and p.role in ('organizer', 'tenant_admin', 'commercial_planner', 'platform_admin');

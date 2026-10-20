-- DEV ONLY. Run in the Supabase SQL editor after you have signed up in the app.
--
-- 1. Makes the FIRST account created in this project an approved organizer.
-- 2. Creates a few sample events owned by that account.
--
-- If your account has a university (you signed up with a tum.de / lmu.de /
-- uni-hamburg.de address) the "official" events use it; otherwise only public
-- events are created.

do $$
declare
  v_user   uuid;
  v_tenant uuid;
begin
  select id, tenant_id into v_user, v_tenant from public.profiles order by created_at limit 1;
  if v_user is null then
    raise exception 'No profile found. Sign up in the app first.';
  end if;

  update public.profiles
     set role = case when v_tenant is null then 'commercial_planner' else 'organizer' end::public.user_role,
         organizer_verified = true
   where id = v_user;

  if v_tenant is not null then
    insert into public.events (tenant_id, organizer_id, title, description, location, starts_at, ends_at,
                               capacity, requires_qr, allow_reviews, categories, status)
    values
      (v_tenant, v_user, 'Campus Hackathon', 'Build something useful in 24 hours. Food provided.',
       'Main Campus, Hall 2', now() + interval '4 days', now() + interval '4 days 6 hours',
       60, true, true, array['Tech', 'Academic'], 'published'),
      (v_tenant, v_user, 'Spring Campus Concert', 'Live music on the lawn. Free for students.',
       'Campus Lawn', now() + interval '2 days', now() + interval '2 days 4 hours',
       300, true, false, array['Music', 'Other'], 'published');
  end if;

  insert into public.events (tenant_id, organizer_id, title, description, location, starts_at, ends_at,
                             capacity, requires_qr, allow_reviews, categories, status)
  values
    (null, v_user, 'Isar Summer Music Festival', 'Public festival along the Isar with local bands and food trucks.',
     'Flaucher Grounds, Munich', now() + interval '6 days', now() + interval '6 days 8 hours',
     null, false, true, array['Music', 'Other'], 'published'),
    (null, v_user, 'Student Group Run', 'Guided run for all fitness levels.',
     'English Garden Entrance', now() + interval '8 days', now() + interval '8 days 2 hours',
     40, false, false, array['Sports'], 'published');
end $$;

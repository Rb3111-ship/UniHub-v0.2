-- "Someone else is editing this event right now."
--
-- While an edit form is open the app says so every few seconds; the answer is
-- the names of the other people who have the same event open. This is only a
-- courtesy notice. The real protection against overwriting each other is in
-- the app's save: it only goes through if the event was not changed since the
-- form was opened.

create table public.event_editors (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.event_editors enable row level security;
-- No policies and no grants: only the function below reads or writes it.
revoke all on table public.event_editors from public, anon, authenticated;

-- p_done = false: "I have this event open" -> returns who else has (last 45 s).
-- p_done = true : "I closed it".
create function public.event_editing(p_event uuid, p_done boolean default false)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_organizer uuid;
begin
  select organizer_id into v_organizer from public.events where id = p_event;
  if v_uid is null or v_organizer is null
     or not (public.can_manage_event(p_event) or public.team_can(v_organizer, 'edit')) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_done then
    delete from public.event_editors where event_id = p_event and user_id = v_uid;
    return '{}';
  end if;

  insert into public.event_editors (event_id, user_id) values (p_event, v_uid)
  on conflict (event_id, user_id) do update set seen_at = now();
  -- Forgotten entries (app closed without saying so) are cleared here.
  delete from public.event_editors where seen_at < now() - interval '1 hour';

  return coalesce((
    select array_agg(case when btrim(p.display_name) = '' then '?' else p.display_name end order by p.display_name)
      from public.event_editors e
      join public.profiles p on p.id = e.user_id
     where e.event_id = p_event and e.user_id <> v_uid and e.seen_at > now() - interval '45 seconds'
  ), '{}');
end $$;

revoke all on function public.event_editing(uuid, boolean) from public, anon, authenticated;
grant execute on function public.event_editing(uuid, boolean) to authenticated;

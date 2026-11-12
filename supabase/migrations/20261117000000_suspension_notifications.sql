-- Tell people when their account is suspended or reinstated
-- (bell in the app + push message). These are account notices, so they are
-- sent regardless of the person's notification preferences.

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('event_cancelled', 'event_changed', 'waitlist_promoted', 'reminder',
                  'request_approved', 'request_rejected', 'event_removed',
                  'confirm_attendance', 'seat_released', 'review_prompt',
                  'account_suspended', 'account_reinstated'));

create function public.profiles_suspension_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.suspended_at is null) <> (new.suspended_at is null) then
    insert into public.notifications (user_id, kind)
    values (new.id, case when new.suspended_at is null then 'account_reinstated' else 'account_suspended' end);
  end if;
  return null;
end $$;

revoke all on function public.profiles_suspension_notify() from public, anon, authenticated;

create trigger profiles_suspension_notify
  after update of suspended_at on public.profiles
  for each row execute function public.profiles_suspension_notify();

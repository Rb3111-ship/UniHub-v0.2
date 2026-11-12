-- The name check runs inside a trigger, which acts as the person saving their name.
-- That person may not call clean_display_name directly, so the trigger function
-- must run with its owner's rights.
alter function public.profiles_name_guard() security definer;

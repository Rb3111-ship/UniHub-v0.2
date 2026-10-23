-- Organizers can now type their own category (picking "Other" in the app).
-- Keep categories short, clean and unique per event, whatever client sends them.

create or replace function public.categories_ok(cats text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(
           c is not null
           and char_length(c) between 2 and 30
           and c = btrim(c)
           and c !~ '\s\s'
           and c !~ '[[:cntrl:]<>{}\[\]\/"`$;=%]'
         ), false)
         and (select count(distinct lower(d)) from unnest(cats) as d) = cardinality(cats)
    from unnest(cats) as c
$$;

alter table public.events drop constraint if exists events_categories_ok;
alter table public.events add constraint events_categories_ok check (public.categories_ok(categories));

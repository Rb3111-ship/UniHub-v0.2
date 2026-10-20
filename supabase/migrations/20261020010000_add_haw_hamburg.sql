-- Add HAW Hamburg (Hochschule für Angewandte Wissenschaften Hamburg).
-- Note: haw-hamburg.de is NOT a subdomain of uni-hamburg.de, so it needs its own tenant.

insert into public.tenants (slug, name_en, name_de, brand_color) values
  ('haw', 'Hamburg University of Applied Sciences', 'Hochschule für Angewandte Wissenschaften Hamburg', '#0072BC')
on conflict (slug) do nothing;

insert into public.tenant_domains (domain, tenant_id)
select 'haw-hamburg.de', t.id from public.tenants t where t.slug = 'haw'
on conflict (domain) do nothing;

-- Accounts that were confirmed before this university existed get their tenant now.
-- (Only fills in profiles that have no tenant yet; never overwrites one.)
select public.assign_tenant_from_email(u.id, u.email)
from auth.users u
where u.email_confirmed_at is not null;

-- Development seed data: the three universities used in the app today.
insert into public.tenants (slug, name_en, name_de, brand_color) values
  ('tum', 'Technical University of Munich', 'Technische Universität München', '#0065BD'),
  ('lmu', 'Ludwig Maximilian University', 'Ludwig-Maximilians-Universität München', '#0F9D58'),
  ('uhh', 'University of Hamburg', 'Universität Hamburg', '#E2001A')
on conflict (slug) do nothing;

insert into public.tenant_domains (domain, tenant_id)
select d.domain, t.id
from (values ('tum.de', 'tum'), ('lmu.de', 'lmu'), ('uni-hamburg.de', 'uhh')) as d(domain, slug)
join public.tenants t on t.slug = d.slug
on conflict (domain) do nothing;

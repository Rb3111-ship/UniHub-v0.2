# UniHub backend (Supabase)

Use a **new, dedicated Supabase project** for UniHub. Do not reuse another app's project.

## Apply the schema

Local (needs Docker + Supabase CLI):

    supabase init            # once; keep the existing supabase/ folder
    supabase start
    supabase db reset        # runs migrations/ then seed.sql

Hosted: create a project, then `supabase link --project-ref <ref>` and `supabase db push`.
Or paste the migration into the SQL editor.

## Data model

    tenants 1--* tenant_domains          (e-mail domain -> university)
    tenants 1--* profiles                (tenant set from confirmed e-mail domain)
    profiles 1--* events                 (tenant_id NULL = public event)
    events 1--* registrations (status: registered | waitlisted | cancelled)
    registrations 1--1 tickets           (secret QR code, checked_in_at)
    tickets 1--0..1 reviews              (one review per ticket)
    events 1--* scan_log

## Rules enforced in the database

- Students see published public events + published events of **their own** university.
- Only verified organizers/planners can create events; official events only for their own tenant.
- Users cannot change their own role, tenant or verified flag (`admin_set_role()` does it).
- Registering, cancelling, check-in and reviews go through functions (`register_for_event`,
  `cancel_registration`, `check_in_ticket`, `submit_review`). Capacity is race-safe, with
  an automatic waitlist.
- A review is "verified" only if the ticket was actually scanned at the door.
- Ratings shown to students come from verified reviews only (`event_rating_stats`).

## Not done yet

- Paid tickets (`register_for_event` rejects `price_cents > 0`).
- Rotating/signed QR tokens (current code is a random 256-bit secret per ticket).
- Row-level security tests (pgTAP) -- the SQL is syntax-checked but not yet run against Postgres.

"""Database security & behaviour tests for UniHub.

Builds throw-away users inside ONE transaction and rolls everything back at the end,
so no test data is ever left in the database. It then tries to break the rules while
acting as: anonymous visitor, student (with/without university), organizer, commercial
planner, tenant admin and platform admin.

Run:  python tools/security_tests.py
Exit code 0 = every check passed.
"""
import json
import sys
import uuid
from pathlib import Path

import psycopg

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dbtool import connect  # noqa: E402

PASS, FAIL = [], []


def check(name: str, ok: bool, detail: str = "") -> None:
    (PASS if ok else FAIL).append(name)
    print(("  ok    " if ok else "  FAIL  ") + name + (f"   <- {detail}" if (detail and not ok) else ""))


class Sim:
    def __init__(self, conn: psycopg.Connection):
        self.c = conn

    # ---- identities -------------------------------------------------------
    def postgres(self):
        self.c.execute("reset role")
        self.c.execute("select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true)")

    def anon(self):
        self.postgres()
        self.c.execute("select set_config('request.jwt.claims', %s, true)", [json.dumps({"role": "anon"})])
        self.c.execute("set local role anon")

    def user(self, uid):
        self.postgres()
        self.c.execute("select set_config('request.jwt.claims', %s, true)",
                       [json.dumps({"sub": str(uid), "role": "authenticated"})])
        self.c.execute("select set_config('request.jwt.claim.sub', %s, true)", [str(uid)])
        self.c.execute("set local role authenticated")

    # ---- helpers ----------------------------------------------------------
    def rows(self, q, args=None):
        return self.c.execute(q, args).fetchall()

    def scalar(self, q, args=None):
        r = self.c.execute(q, args).fetchone()
        return r[0] if r else None

    def fails(self, name, q, args=None, contains=None):
        """The statement must be refused (error)."""
        try:
            with self.c.transaction():
                self.c.execute(q, args)
        except psycopg.Error as e:
            msg = str(e).lower()
            if contains and contains.lower() not in msg:
                check(name, False, f"failed, but with: {msg.splitlines()[0][:120]}")
            else:
                check(name, True)
            return
        check(name, False, "statement unexpectedly SUCCEEDED")

    def affects_nothing(self, name, q, args=None):
        """The statement is allowed to run but must change 0 rows (RLS filtered it)."""
        try:
            with self.c.transaction():
                cur = self.c.execute(q, args)
                n = cur.rowcount
        except psycopg.Error as e:
            check(name, True)  # refusing outright is fine too
            return
        check(name, n == 0, f"changed {n} row(s)")

    def call(self, q, args=None):
        """Run and return (result, error_message)."""
        try:
            with self.c.transaction():
                cur = self.c.execute(q, args)
                return (cur.fetchone()[0] if cur.description else None), None
        except psycopg.Error as e:
            return None, str(e).lower()


def main() -> int:
    conn = connect()
    s = Sim(conn)
    tag = uuid.uuid4().hex[:8]
    try:
        run(s, tag)
    finally:
        conn.rollback()  # nothing from this run is kept
        conn.close()
    print()
    print(f"{len(PASS)} passed, {len(FAIL)} failed")
    for n in FAIL:
        print("  FAILED:", n)
    return 1 if FAIL else 0


def run(s: Sim, tag: str) -> None:
    c = s.c
    s.postgres()

    def tenant_id(slug):
        return s.scalar("select id from public.tenants where slug = %s", [slug])

    tum, haw, lmu = tenant_id("tum"), tenant_id("haw"), tenant_id("lmu")
    assert tum and haw and lmu, "seed universities missing"

    def mk_user(email, confirmed=True):
        s.postgres()
        uid = uuid.uuid4()
        c.execute(
            "insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, "
            "raw_user_meta_data, created_at, updated_at) values "
            "('00000000-0000-0000-0000-000000000000', %s, 'authenticated', 'authenticated', %s, "
            "case when %s then now() else null end, %s::jsonb, now(), now())",
            [uid, email, confirmed, json.dumps({"display_name": email.split("@")[0]})])
        return uid

    def promote(uid, role, verified=True):
        s.postgres()
        c.execute("update public.profiles set role = %s::public.user_role, organizer_verified = %s where id = %s",
                  [role, verified, uid])

    def mk_event(org, tenant, title, *, status="published", start="now() + interval '1 day'",
                 end="now() + interval '1 day 2 hours'", capacity=None, price=0, qr=True, reviews=True):
        s.postgres()
        return s.scalar(
            f"insert into public.events (tenant_id, organizer_id, title, location, starts_at, ends_at, capacity, "
            f"price_cents, requires_qr, allow_reviews, categories, status) values "
            f"(%s, %s, %s, 'Somewhere', {start}, {end}, %s, %s, %s, %s, array['Tech'], %s::public.event_status) "
            f"returning id", [tenant, org, title, capacity, price, qr, reviews, status])

    def code_of(uid, ev):
        s.postgres()
        return s.scalar("select code from public.tickets where user_id = %s and event_id = %s", [uid, ev])

    # reset ticket numbering at the end only if no real tickets exist (cosmetic)
    real_tickets = s.scalar("select count(*) from public.tickets")

    # ------------------------------------------------------------------ actors
    org_tum = mk_user(f"org-{tag}@tum.de");        promote(org_tum, "organizer")
    org_haw = mk_user(f"org-{tag}@haw-hamburg.de"); promote(org_haw, "organizer")
    org_unverified = mk_user(f"unv-{tag}@tum.de");  promote(org_unverified, "organizer", verified=False)
    commercial = mk_user(f"biz-{tag}@example.com"); promote(commercial, "commercial_planner")
    t_admin = mk_user(f"admin-{tag}@haw-hamburg.de"); promote(t_admin, "tenant_admin")
    p_admin = mk_user(f"root-{tag}@example.com");   promote(p_admin, "platform_admin")
    stu_tum = mk_user(f"s1-{tag}@tum.de")
    stu_tum2 = mk_user(f"s2-{tag}@tum.de")
    stu_haw = mk_user(f"s3-{tag}@haw-hamburg.de")
    stu_pub = mk_user(f"s4-{tag}@gmail.com")

    print("\n[1] Sign-up trigger: university from CONFIRMED e-mail domain")
    check("tum.de address -> TUM", s.scalar("select tenant_id from public.profiles where id=%s", [stu_tum]) == tum)
    check("haw-hamburg.de address -> HAW", s.scalar("select tenant_id from public.profiles where id=%s", [stu_haw]) == haw)
    check("gmail address -> no university", s.scalar("select tenant_id from public.profiles where id=%s", [stu_pub]) is None)
    late = mk_user(f"late-{tag}@tum.de", confirmed=False)
    check("UNconfirmed tum.de address gets NO university", s.scalar("select tenant_id from public.profiles where id=%s", [late]) is None)
    c.execute("update auth.users set email_confirmed_at = now() where id = %s", [late])
    check("...but gets TUM once confirmed", s.scalar("select tenant_id from public.profiles where id=%s", [late]) == tum)
    sub = mk_user(f"sub-{tag}@stud.tum.de")
    check("subdomain stud.tum.de -> TUM", s.scalar("select tenant_id from public.profiles where id=%s", [sub]) == tum)
    for bad in (f"x-{tag}@evil-tum.de", f"x-{tag}@nottum.de", f"x-{tag}@tum.de.evil.com", f"x-{tag}@tum.dex.com"):
        u = mk_user(bad)
        check(f"look-alike domain {bad.split('@')[1]} gets NO university",
              s.scalar("select tenant_id from public.profiles where id=%s", [u]) is None)

    # ------------------------------------------------------------------ data
    ev_pub = mk_event(commercial, None, "Public fest")
    ev_tum = mk_event(org_tum, tum, "TUM official")
    ev_haw = mk_event(org_haw, haw, "HAW official")
    ev_draft = mk_event(org_tum, tum, "TUM draft", status="draft")
    ev_cancelled = mk_event(org_tum, tum, "TUM cancelled", status="cancelled")
    ev_past = mk_event(org_tum, tum, "TUM past", start="now() - interval '3 days'", end="now() - interval '2 days'")
    ev_paid = mk_event(org_tum, tum, "TUM paid", price=500)

    print("\n[2] Anonymous visitor (not signed in)")
    s.anon()
    vis = {r[0] for r in s.rows("select title from public.events")}
    check("sees public published event", "Public fest" in vis)
    check("does NOT see university events", not ({"TUM official", "HAW official"} & vis), str(vis))
    check("does NOT see drafts/cancelled", not ({"TUM draft", "TUM cancelled"} & vis))
    for t in ("profiles", "registrations", "tickets", "scan_log", "tenant_domains", "event_stats"):
        s.fails(f"cannot read {t}", f"select * from public.{t} limit 1", contains="permission denied")
    check("can read universities list", len(s.rows("select * from public.tenants")) >= 4)
    check("can read rating stats view", s.rows("select * from public.event_rating_stats") is not None)
    s.fails("cannot insert an event", "insert into public.events (organizer_id,title,location,starts_at,ends_at) "
            "values (%s,'x','y',now(),now()+interval '1 h')", [commercial], contains="permission denied")
    s.fails("cannot insert a tenant", "insert into public.tenants (slug,name_en,name_de) values ('x','x','x')", contains="permission denied")
    for fn, args in (("register_for_event", [ev_pub]), ("cancel_registration", [ev_pub]),
                     ("check_in_ticket", ["abc", ev_pub]), ("admin_set_role", [stu_pub, "platform_admin", True]),
                     ("submit_review", [ev_pub, 5, "x"])):
        ph = ",".join(["%s"] * len(args))
        s.fails(f"cannot call {fn}", f"select public.{fn}({ph})", args, contains="permission denied")
    s.fails("internal function issue_ticket is not callable", "select public.issue_ticket(%s)", [uuid.uuid4()], contains="permission denied")
    s.fails("internal function promote_waitlist is not callable", "select public.promote_waitlist(%s)", [ev_pub], contains="permission denied")
    s.fails("internal function assign_tenant_from_email is not callable", "select public.assign_tenant_from_email(%s, 'a@tum.de')", [stu_pub], contains="permission denied")

    print("\n[3] Students: what each can see (university isolation)")
    s.user(stu_tum)
    vis = {r[0] for r in s.rows("select title from public.events")}
    check("TUM student sees TUM + public events", {"TUM official", "Public fest"} <= vis)
    check("TUM student does NOT see HAW events", "HAW official" not in vis)
    check("student does NOT see drafts or cancelled", not ({"TUM draft", "TUM cancelled"} & vis))
    s.user(stu_haw)
    vis = {r[0] for r in s.rows("select title from public.events")}
    check("HAW student sees HAW + public, not TUM", "HAW official" in vis and "Public fest" in vis and "TUM official" not in vis)
    s.user(stu_pub)
    vis = {r[0] for r in s.rows("select title from public.events")}
    check("student without university sees only public events", vis == {"Public fest"} or ("Public fest" in vis and not ({"TUM official", "HAW official"} & vis)), str(vis))

    print("\n[4] Privilege escalation attempts")
    s.user(stu_pub)
    for col, val in (("role", "'platform_admin'::public.user_role"), ("organizer_verified", "true"),
                     ("tenant_id", f"'{tum}'::uuid")):
        s.fails(f"student cannot set own {col}", f"update public.profiles set {col} = {val} where id = %s", [stu_pub],
                contains="permission denied")
    s.fails("student cannot re-point profile id", "update public.profiles set id = %s where id = %s", [uuid.uuid4(), stu_pub], contains="permission denied")
    _, err = s.call("update public.profiles set display_name = 'New name' where id = %s", [stu_pub])
    check("student CAN rename self", err is None, str(err))
    _, err = s.call("update public.profiles set locale = 'de' where id = %s", [stu_pub]); check("student CAN save their language", err is None, str(err))
    s.fails("an unsupported language is rejected", "update public.profiles set locale = 'xx' where id = %s", [stu_pub])
    s.fails("a 81-character name is rejected", "update public.profiles set display_name = %s where id = %s", ["n" * 81, stu_pub])
    s.affects_nothing("student cannot rename someone else", "update public.profiles set display_name='hacked' where id = %s", [stu_tum])
    check("student reads only own profile", s.scalar("select count(*) from public.profiles") == 1)
    s.fails("student cannot publish events", "insert into public.events (organizer_id,tenant_id,title,location,starts_at,ends_at) "
            "values (%s,null,'Spam','x',now()+interval '1 d',now()+interval '2 d')", [stu_pub], contains="row-level security")
    _, err = s.call("select public.admin_set_role(%s, 'platform_admin', true)", [stu_pub])
    check("student cannot promote self via admin_set_role", err is not None and "not_authorized" in err, str(err))

    print("\n[5] Who may publish events")
    def try_insert(uid, tenant, org=None, title="T"):
        s.user(uid)
        return s.call("insert into public.events (organizer_id,tenant_id,title,location,starts_at,ends_at,status) "
                      "values (%s,%s,%s,'Room 1',now()+interval '1 d',now()+interval '2 d','published') returning id",
                      [org or uid, tenant, title + tag])
    _, err = try_insert(org_tum, tum);            check("verified organizer can publish for OWN university", err is None, str(err))
    _, err = try_insert(org_tum, haw);            check("organizer cannot publish for ANOTHER university", err is not None)
    _, err = try_insert(org_tum, None);           check("university organizer cannot publish as public/commercial", err is not None)
    _, err = try_insert(org_unverified, tum);     check("UNverified organizer cannot publish", err is not None)
    _, err = try_insert(commercial, None);        check("verified commercial planner can publish public events", err is None, str(err))
    _, err = try_insert(commercial, tum);         check("commercial planner cannot publish official events", err is not None)
    _, err = try_insert(org_tum, tum, org=org_haw); check("cannot publish AS someone else (organizer_id spoof)", err is not None)
    s.user(org_tum)
    s.fails("owner cannot hand the event to another organizer", "update public.events set organizer_id = %s where id = %s", [org_haw, ev_tum])
    s.fails("owner cannot move event to another university", "update public.events set tenant_id = %s where id = %s", [haw, ev_tum])
    s.postgres()
    s.fails("even the immutability trigger blocks it (defence in depth)", "update public.events set organizer_id = %s where id = %s", [org_haw, ev_tum], contains="immutable")
    s.user(org_tum)
    s.user(org_haw)
    s.affects_nothing("another organizer cannot edit an event they don't own", "update public.events set title='pwn' where id = %s", [ev_tum])
    s.affects_nothing("another organizer cannot delete it either", "delete from public.events where id = %s", [ev_tum])
    s.user(org_tum)
    check("organizer sees own draft", ev_draft in {r[0] for r in s.rows("select id from public.events")})
    s.affects_nothing("organizer cannot delete a PUBLISHED event", "delete from public.events where id = %s", [ev_tum])
    s.fails("organizer cannot write is_official (generated)", "update public.events set is_official = false where id = %s", [ev_tum])

    print("\n[6] Registration rules")
    s.user(stu_tum)
    r, err = s.call("select (public.register_for_event(%s)).status", [ev_tum]);  check("TUM student registers for TUM event", r == "registered", str(err))
    r, err = s.call("select (public.register_for_event(%s)).status", [ev_tum]);  check("registering twice is idempotent", r == "registered", str(err))
    check("exactly one registration + one ticket", s.scalar("select count(*) from public.registrations where event_id=%s", [ev_tum]) == 1 and s.scalar("select count(*) from public.tickets where event_id=%s", [ev_tum]) == 1)
    for label, ev, expect in (("another university's event", ev_haw, "event_not_available"), ("a draft", ev_draft, "event_not_available"),
                              ("a cancelled event", ev_cancelled, "event_not_available"), ("a finished event", ev_past, "event_over"),
                              ("a paid event", ev_paid, "paid_events_not_supported_yet"), ("a non-existent event", uuid.uuid4(), "event_not_available")):
        _, err = s.call("select public.register_for_event(%s)", [ev])
        check(f"cannot register for {label}", err is not None and expect in err, str(err))
    s.user(stu_pub)
    _, err = s.call("select public.register_for_event(%s)", [ev_tum]);  check("no-university student cannot register for a university event", err is not None)
    r, err = s.call("select (public.register_for_event(%s)).status", [ev_pub]);  check("no-university student can register for public event", r == "registered", str(err))

    print("\n[7] Capacity and waitlist")
    ev_cap = mk_event(commercial, None, "Capacity 1", capacity=1)
    s.user(stu_tum); r1, _ = s.call("select (public.register_for_event(%s)).status", [ev_cap])
    s.user(stu_haw); r2, _ = s.call("select (public.register_for_event(%s)).status", [ev_cap])
    s.user(stu_pub); r3, _ = s.call("select (public.register_for_event(%s)).status", [ev_cap])
    check("first person gets the seat", r1 == "registered", str(r1))
    check("next people are waitlisted (never over capacity)", (r2, r3) == ("waitlisted", "waitlisted"), f"{r2},{r3}")
    s.postgres()
    # All of this runs in one transaction (same now()), so make the queue order explicit.
    c.execute("update public.registrations set created_at = now() - interval '1 minute' where event_id = %s and user_id = %s", [ev_cap, stu_haw])
    check("waitlisted users have NO ticket", s.scalar("select count(*) from public.tickets where event_id=%s", [ev_cap]) == 1)
    s.postgres(); old_code = code_of(stu_tum, ev_cap)
    s.user(stu_tum); s.call("select public.cancel_registration(%s)", [ev_cap])
    s.postgres()
    check("cancel promotes the OLDEST waitlisted user", s.scalar("select status from public.registrations where event_id=%s and user_id=%s", [ev_cap, stu_haw]) == "registered")
    check("...who now has a ticket; the next one still waits",
          code_of(stu_haw, ev_cap) is not None and s.scalar("select status from public.registrations where event_id=%s and user_id=%s", [ev_cap, stu_pub]) == "waitlisted")
    check("cancelled ticket is voided", s.scalar("select voided_at is not null from public.tickets where event_id=%s and user_id=%s", [ev_cap, stu_tum]))
    s.user(commercial)
    s.call("update public.events set capacity = 3 where id = %s", [ev_cap])
    s.postgres()
    check("raising capacity promotes the waitlist automatically", s.scalar("select status from public.registrations where event_id=%s and user_id=%s", [ev_cap, stu_pub]) == "registered")
    s.user(stu_tum); r, err = s.call("select (public.register_for_event(%s)).status", [ev_cap])
    check("re-registering after cancelling works (gets a seat again)", r == "registered", str(err))
    s.postgres()
    codes = [x[0] for x in s.rows("select code from public.tickets")]
    check("all ticket codes are unique and 64 chars", len(codes) == len(set(codes)) and all(len(x) == 64 for x in codes))
    check("re-issued ticket has a NEW secret (old QR code is dead)", code_of(stu_tum, ev_cap) != old_code)

    print("\n[8] Who can read registrations and tickets")
    s.user(stu_haw)
    check("student sees only their own registrations", all(r[0] == stu_haw for r in s.rows("select user_id from public.registrations")))
    check("student sees only their own tickets", all(r[0] == stu_haw for r in s.rows("select user_id from public.tickets")))
    for t, q in (("registrations", "update public.registrations set status='registered'"),
                 ("tickets", "update public.tickets set checked_in_at = now()"),
                 ("scan_log", "update public.scan_log set result='granted'")):
        s.fails(f"student cannot directly UPDATE {t}", q, contains="permission denied")
    s.fails("student cannot INSERT a registration", "insert into public.registrations (event_id,user_id,status) values (%s,%s,'registered')", [ev_pub, stu_haw], contains="permission denied")
    s.fails("student cannot forge a ticket", "insert into public.tickets (registration_id,event_id,user_id) select id,event_id,user_id from public.registrations limit 1", contains="permission denied")
    s.fails("student cannot DELETE registrations", "delete from public.registrations", contains="permission denied")
    s.user(commercial)
    check("organizer sees registrations only for own events",
          {r[0] for r in s.rows("select event_id from public.registrations")} <= {ev_pub, ev_cap})
    s.user(org_tum)
    check("TUM organizer cannot see registrations of other organizers' events",
          ev_cap not in {r[0] for r in s.rows("select event_id from public.registrations")})

    print("\n[9] Door check-in")
    ev_door = mk_event(org_tum, tum, "Door test")
    s.user(stu_tum);  s.call("select public.register_for_event(%s)", [ev_door])
    s.user(stu_tum2); s.call("select public.register_for_event(%s)", [ev_door])
    s.postgres()
    code1, code2 = code_of(stu_tum, ev_door), code_of(stu_tum2, ev_door)
    s.user(stu_tum)
    _, err = s.call("select public.check_in_ticket(%s, %s)", [code1, ev_door]); check("a student cannot check people in", err is not None and ("not_authorized" in err or "42501" in err), str(err))
    s.user(org_haw)
    _, err = s.call("select public.check_in_ticket(%s, %s)", [code1, ev_door]); check("an organizer of ANOTHER event cannot check in", err is not None)
    s.user(commercial)
    _, err = s.call("select public.check_in_ticket(%s, %s)", [code1, ev_door]); check("a commercial planner cannot check in a university event", err is not None)
    s.user(org_tum)
    r, err = s.call("select public.check_in_ticket(%s, %s)", [code1, ev_door]); check("owner checks in a valid ticket", err is None and r and r["ok"] and r["result"] == "granted", f"{r} {err}")
    check("result includes the guest name", bool(r and r.get("attendee_name")))
    r, _ = s.call("select public.check_in_ticket(%s, %s)", [code1, ev_door]); check("same ticket twice -> already_used", r and r["result"] == "already_used" and not r["ok"], str(r))
    r, _ = s.call("select public.check_in_ticket(%s, %s)", [code2, ev_tum]);  check("ticket scanned at the WRONG event -> wrong_event", r and r["result"] == "wrong_event", str(r))
    r, _ = s.call("select public.check_in_ticket(%s, %s)", ["0" * 64, ev_door]); check("random code -> invalid", r and r["result"] == "invalid", str(r))
    for junk in ("", "' or 1=1 --", "a" * 5000, "%", "unihub:1:" + "0" * 64):
        r, err = s.call("select public.check_in_ticket(%s, %s)", [junk, ev_door])
        check(f"junk code {junk[:12]!r} handled safely", err is None and r and r["result"] == "invalid", f"{r} {err}")
    s.user(stu_tum2); s.call("select public.cancel_registration(%s)", [ev_door])
    s.user(org_tum)
    r, _ = s.call("select public.check_in_ticket(%s, %s)", [code2, ev_door]); check("cancelled ticket -> cancelled", r and r["result"] == "cancelled", str(r))
    s.user(stu_tum)
    _, err = s.call("select public.cancel_registration(%s)", [ev_door]); check("cannot cancel after being checked in", err is not None and "already_checked_in" in err, str(err))
    s.user(org_tum)
    check("scan log recorded the scans", s.scalar("select count(*) from public.scan_log where event_id = %s", [ev_door]) >= 5)
    s.user(stu_tum)
    check("students see an empty scan log", s.scalar("select count(*) from public.scan_log") == 0)
    s.user(t_admin)
    ev_haw_door = mk_event(org_haw, haw, "HAW door")
    s.user(stu_haw); s.call("select public.register_for_event(%s)", [ev_haw_door])
    s.postgres(); hc = code_of(stu_haw, ev_haw_door)
    s.user(t_admin)
    r, err = s.call("select public.check_in_ticket(%s, %s)", [hc, ev_haw_door]); check("tenant admin may check in at own university's events", err is None and r and r["ok"], f"{r} {err}")
    s.user(org_tum)
    _, err = s.call("select public.check_in_ticket(%s, %s)", [hc, ev_haw_door]); check("TUM organizer cannot check in at a HAW event", err is not None)

    print("\n[10] Reviews")
    ev_rev = mk_event(commercial, None, "Review QR", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=True, reviews=True)
    ev_rev_free = mk_event(commercial, None, "Review open", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=False, reviews=True)
    ev_rev_off = mk_event(commercial, None, "Review off", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=False, reviews=False)
    ev_rev_future = mk_event(commercial, None, "Review future", reviews=True, qr=False)
    for e in (ev_rev, ev_rev_free, ev_rev_off, ev_rev_future):
        s.user(stu_pub); s.call("select public.register_for_event(%s)", [e])
    s.user(stu_pub)
    _, err = s.call("select public.submit_review(%s,5,'x')", [ev_rev_future]); check("cannot review an event that has not started", err is not None and "event_not_started" in err, str(err))
    _, err = s.call("select public.submit_review(%s,5,'x')", [ev_rev_off]);    check("cannot review when reviews are disabled", err is not None and "reviews_not_allowed" in err, str(err))
    _, err = s.call("select public.submit_review(%s,5,'x')", [ev_rev]);        check("QR event: cannot review before check-in", err is not None and "check_in_required" in err, str(err))
    s.user(stu_tum)
    _, err = s.call("select public.submit_review(%s,5,'x')", [ev_rev_free]);   check("cannot review without a ticket", err is not None and "no_ticket" in err, str(err))
    s.user(stu_pub)
    for bad_rating in (0, 6, -1, 100):
        _, err = s.call("select public.submit_review(%s,%s,'x')", [ev_rev_free, bad_rating]); check(f"rating {bad_rating} is rejected", err is not None)
    _, err = s.call("select public.submit_review(%s,5,'   ')", [ev_rev_free]);   check("blank comment is rejected", err is not None)
    _, err = s.call("select public.submit_review(%s,5,%s)", [ev_rev_free, "a" * 2001]); check("2001-char comment is rejected", err is not None)
    r, err = s.call("select (public.submit_review(%s,3,'ok',false)).is_verified", [ev_rev_free]); check("review without check-in is saved as UNverified", err is None and r is False, f"{r} {err}")
    _, err = s.call("select public.submit_review(%s,4,'again')", [ev_rev_free]);  check("a second review for the same ticket is rejected", err is not None)
    s.postgres(); rc = code_of(stu_pub, ev_rev)
    s.user(commercial); s.call("select public.check_in_ticket(%s,%s)", [rc, ev_rev])
    s.user(stu_pub)
    r, err = s.call("select (public.submit_review(%s,5,'great')).is_verified", [ev_rev]); check("review after a real check-in is VERIFIED", err is None and r is True, f"{r} {err}")
    s.fails("cannot insert a review directly (forge is_verified)", "insert into public.reviews (event_id,ticket_id,user_id,rating,comment,is_verified) "
            "select event_id,id,user_id,5,'forged',true from public.tickets limit 1", contains="permission denied")
    s.fails("cannot edit a review", "update public.reviews set rating = 1", contains="permission denied")
    s.fails("cannot delete a review", "delete from public.reviews", contains="permission denied")
    stats = {r[0]: (float(r[1]), r[2]) for r in s.rows("select event_id, average_rating, review_count from public.event_rating_stats")}
    check("rating stats count the verified review", stats.get(ev_rev) == (5.0, 1), str(stats.get(ev_rev)))
    check("rating stats IGNORE the unverified review", ev_rev_free not in stats)
    s.anon()
    vis = {r[0] for r in s.rows("select event_id from public.reviews")}
    check("anonymous visitors see verified reviews only", ev_rev in vis and ev_rev_free not in vis)
    s.user(stu_tum)
    check("other students cannot read someone's unverified review", ev_rev_free not in {r[0] for r in s.rows("select event_id from public.reviews")})
    s.user(commercial)
    check("the organizer sees unverified feedback on their event", ev_rev_free in {r[0] for r in s.rows("select event_id from public.reviews")})
    s.user(org_tum)
    check("a different organizer cannot see it", ev_rev_free not in {r[0] for r in s.rows("select event_id from public.reviews")})

    print("\n[11] Profiles and admin roles")
    s.user(stu_tum)
    check("organizer_profiles view lists no students", all(r[0] != stu_tum for r in s.rows("select id from public.organizer_profiles")))
    check("organizer_profiles exposes no e-mail column", "email" not in {r[0] for r in s.rows("select column_name from information_schema.columns where table_name='organizer_profiles'")})
    s.user(t_admin)
    check("tenant admin sees profiles of own university only", all(r[0] == haw for r in s.rows("select tenant_id from public.profiles")))
    _, err = s.call("select public.admin_set_role(%s,'organizer',true)", [stu_haw]); check("tenant admin can approve an organizer in own university", err is None, str(err))
    _, err = s.call("select public.admin_set_role(%s,'organizer',true)", [stu_tum]); check("tenant admin cannot approve in ANOTHER university", err is not None)
    _, err = s.call("select public.admin_set_role(%s,'platform_admin',true)", [stu_haw]); check("tenant admin cannot create platform admins", err is not None)
    _, err = s.call("select public.admin_set_role(%s,'tenant_admin',true)", [stu_haw]); check("tenant admin cannot create other tenant admins", err is not None)
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'commercial_planner',true)", [stu_pub]); check("platform admin can set any role", err is None, str(err))
    s.postgres()
    s.user(stu_tum)
    s.affects_nothing("student cannot change a university's name", "update public.tenants set name_en='pwned'")
    s.fails("student cannot add an e-mail domain to a university", "insert into public.tenant_domains (domain, tenant_id) select 'evil.com', id from public.tenants limit 1")

    print("\n[12] Storage (event images)")
    def upload(uid, folder):
        s.user(uid)
        return s.call("insert into storage.objects (bucket_id, name, owner) values ('event-images', %s, %s)",
                      [f"{folder}/{tag}.png", uid])
    _, err = upload(commercial, commercial);  check("organizer can upload into own folder", err is None, str(err))
    _, err = upload(commercial, org_tum);     check("organizer cannot upload into someone else's folder", err is not None)
    _, err = upload(stu_tum2, stu_tum2);      check("a plain student cannot upload event images", err is not None, str(err))
    _, err = upload(org_unverified, org_unverified); check("an UNapproved organizer cannot upload event images", err is not None, "unapproved organizer could upload")
    s.anon()
    _, err = s.call("insert into storage.objects (bucket_id, name) values ('event-images', %s)", [f"x/{tag}.png"]); check("anonymous cannot upload", err is not None)
    s.user(org_tum)
    s.affects_nothing("cannot delete another user's image", "delete from storage.objects where bucket_id='event-images' and name = %s", [f"{commercial}/{tag}.png"])
    check("an organizer cannot list other people's posters", s.scalar("select count(*) from storage.objects where bucket_id='event-images' and name = %s", [f"{commercial}/{tag}.png"]) == 0)
    s.user(commercial)
    check("an organizer can list their own posters", s.scalar("select count(*) from storage.objects where bucket_id='event-images' and name = %s", [f"{commercial}/{tag}.png"]) == 1)
    s.anon()
    check("anonymous cannot list the poster bucket", s.scalar("select count(*) from storage.objects where bucket_id='event-images'") == 0)
    s.postgres()
    b = s.rows("select public, file_size_limit, allowed_mime_types from storage.buckets where id='event-images'")[0]
    check("bucket has a size limit and image-only types", b[1] is not None and b[1] <= 10_000_000 and set(b[2] or []) <= {"image/jpeg", "image/png", "image/webp"}, str(b))

    print("\n[14] Event cancellation and image paths")
    ev_c = mk_event(org_tum, tum, "To cancel")
    s.user(stu_tum);  s.call("select public.register_for_event(%s)", [ev_c])
    s.postgres(); cc = code_of(stu_tum, ev_c)
    s.user(org_tum)
    _, err = s.call("update public.events set status = 'cancelled' where id = %s", [ev_c]); check("organizer can cancel own event", err is None, str(err))
    s.user(stu_tum)
    check("a registered attendee still sees the cancelled event", s.scalar("select status::text from public.events where id = %s", [ev_c]) == "cancelled")
    s.user(stu_tum2)
    check("someone who never registered does not see it", s.scalar("select count(*) from public.events where id = %s", [ev_c]) == 0)
    _, err = s.call("select public.register_for_event(%s)", [ev_c]); check("cannot register for a cancelled event", err is not None)
    s.user(org_tum)
    _, err = s.call("update public.events set status = 'published' where id = %s", [ev_c]); check("a cancelled event cannot be re-opened", err is not None and "cancelled_is_final" in err, str(err))
    _, err = s.call("update public.events set status = 'draft' where id = %s", [ev_tum]); check("a published event cannot go back to draft", err is not None and "cannot_unpublish" in err, str(err))
    r, _ = s.call("select public.check_in_ticket(%s, %s)", [cc, ev_c]); check("tickets of a cancelled event do not check in", r and r["result"] == "cancelled" and not r["ok"], str(r))
    for label, path in (("not a uuid folder", "bad.png"), ("someone else's folder", f"{org_haw}/a.png"),
                        ("path traversal", f"{org_tum}/../x.png"), ("nested folders", f"{org_tum}/a/b.png"),
                        ("spaces and symbols", f"{org_tum}/a b$.png"), ("over-long name", f"{org_tum}/" + "a" * 101)):
        _, err = s.call("update public.events set image_path = %s where id = %s", [path, ev_tum]); check(f"image path rejected: {label}", err is not None, "accepted a bad path")
    _, err = s.call("update public.events set image_path = %s where id = %s", [f"{org_tum}/{tag}.png", ev_tum]); check("image path accepted: own folder", err is None, str(err))

    print("\n[15] Organizer requests (becoming an organizer)")
    rq_haw = mk_user(f"rq1-{tag}@haw-hamburg.de")
    rq_pub = mk_user(f"rq2-{tag}@gmail.com")
    rq_tum = mk_user(f"rq3-{tag}@tum.de")
    s.user(rq_haw)
    _, err = s.call("select public.request_organizer_access('organizer', 'HAW Film Club', 'We screen films', 'Chair', '+49 40 1234567')"); check("student with a university can request organizer access", err is None, str(err))
    _, err = s.call("select public.request_organizer_access('organizer', 'Again', '', 'Chair', '+49 40 1234567')"); check("a second pending request is refused", err is not None and "request_pending" in err, str(err))
    for bad in ("platform_admin", "tenant_admin", "student"):
        _, err = s.call("select public.request_organizer_access(%s::public.user_role, 'X Org', '', 'Chair', '+49 40 1234567')", [bad]); check(f"cannot request the {bad} role", err is not None, "accepted")
    s.user(rq_pub)
    _, err = s.call("select public.request_organizer_access('organizer', 'Fake Uni Club', '', 'Chair', '+49 40 1234567')"); check("no university -> cannot request university organizer", err is not None and "no_university" in err, str(err))
    _, err = s.call("select public.request_organizer_access('commercial_planner', 'Acme Events', 'We run concerts', 'Chair', '+49 40 1234567')"); check("anyone can request commercial planner access", err is None, str(err))
    _, err = s.call("select public.request_organizer_access('commercial_planner', %s, '', 'Chair', '+49 40 1234567')", ["x"]); check("request needs a real organization name", err is not None)
    s.user(rq_tum)
    s.call("select public.request_organizer_access('organizer', 'TUM Robotics', '', 'Chair', '+49 40 1234567')")
    s.user(org_tum)
    _, err = s.call("select public.request_organizer_access('organizer', 'Already one', '', 'Chair', '+49 40 1234567')"); check("an existing organizer cannot request again", err is not None and "already_organizer" in err, str(err))
    s.user(rq_haw)
    for label, q in (("insert", "insert into public.organizer_requests (user_id, requested_role, organization_name) values (%s, 'organizer', 'Hack')"),
                     ("update", "update public.organizer_requests set status = 'approved'"),
                     ("delete", "delete from public.organizer_requests")):
        s.fails(f"cannot {label} requests directly", q, [rq_haw] if "%s" in q else None, contains="permission denied")
    check("a user sees only their own request", {r[0] for r in s.rows("select user_id from public.organizer_requests")} == {rq_haw})
    s.user(stu_tum2)
    check("other users see no requests", s.scalar("select count(*) from public.organizer_requests") == 0)
    s.user(t_admin)
    seen = {r[0] for r in s.rows("select user_id from public.organizer_requests")}
    check("tenant admin sees organizer requests of THEIR university only", seen == {rq_haw}, str(seen))
    s.user(p_admin)
    seen = {r[0] for r in s.rows("select user_id from public.organizer_requests")}
    check("platform admin sees all requests", {rq_haw, rq_pub, rq_tum} <= seen)
    req = lambda uid: s.scalar("select id from public.organizer_requests where user_id = %s and status = 'pending'", [uid])
    s.postgres(); r_haw, r_pub, r_tum = req(rq_haw), req(rq_pub), req(rq_tum)
    s.user(rq_tum)
    _, err = s.call("select public.review_organizer_request(%s, true)", [r_tum]); check("a student cannot approve requests (not even their own)", err is not None and "not_authorized" in err, str(err))
    s.user(org_tum)
    _, err = s.call("select public.review_organizer_request(%s, true)", [r_tum]); check("an organizer cannot approve requests", err is not None)
    s.user(t_admin)
    _, err = s.call("select public.review_organizer_request(%s, true)", [r_pub]); check("tenant admin cannot approve a commercial planner", err is not None)
    _, err = s.call("select public.review_organizer_request(%s, true)", [r_tum]); check("tenant admin cannot approve another university's request", err is not None)
    _, err = s.call("select public.review_organizer_request(%s, true, 'Welcome')", [r_haw]); check("tenant admin approves a request from their university", err is None, str(err))
    s.postgres()
    row = s.rows("select role::text, organizer_verified from public.profiles where id = %s", [rq_haw])[0]
    check("approval makes the user a verified organizer", row == ("organizer", True), str(row))
    row = s.rows("select status::text, reviewed_by, review_note from public.organizer_requests where id = %s", [r_haw])[0]
    check("the review is recorded (who, when, note)", row[0] == "approved" and row[1] == t_admin and row[2] == "Welcome", str(row))
    s.user(rq_haw)
    _, err = s.call("insert into public.events (organizer_id,tenant_id,title,location,starts_at,ends_at,status) values (%s,%s,'Film night','Hall',now()+interval '1 d',now()+interval '2 d','published')", [rq_haw, haw])
    check("a newly approved organizer can publish for their university", err is None, str(err))
    s.user(p_admin)
    _, err = s.call("select public.review_organizer_request(%s, true)", [r_haw]); check("a request cannot be reviewed twice", err is not None and "already_reviewed" in err, str(err))
    _, err = s.call("select public.review_organizer_request(%s, false, 'Not enough info')", [r_pub]); check("platform admin can reject a request", err is None, str(err))
    s.postgres()
    check("a rejected user stays a student", s.scalar("select role::text from public.profiles where id = %s", [rq_pub]) == "student")
    s.user(rq_pub)
    _, err = s.call("select public.request_organizer_access('commercial_planner', 'Acme Events', 'Second try', 'Chair', '+49 40 1234567')"); check("after a rejection the user may apply again", err is None, str(err))
    s.postgres()
    s.c.execute("update public.profiles set role = 'tenant_admin' where id = %s", [rq_tum])
    s.user(p_admin)
    s.call("select public.review_organizer_request(%s, true)", [r_tum])
    s.postgres()
    check("approving never downgrades an admin", s.scalar("select role::text from public.profiles where id = %s", [rq_tum]) == "tenant_admin")

    print("\n[16] Admin user list")
    s.anon()
    s.fails("anonymous cannot list users", "select * from public.admin_list_users()", contains="permission denied")
    s.user(stu_tum)
    _, err = s.call("select * from public.admin_list_users()"); check("a student cannot list users", err is not None and "not_authorized" in err, str(err))
    s.user(org_tum)
    _, err = s.call("select * from public.admin_list_users()"); check("an organizer cannot list users", err is not None)
    s.user(t_admin)
    rows = s.rows("select tenant_id, email from public.admin_list_users()")
    check("tenant admin lists only their university's users, with e-mail", rows and all(r[0] == haw and r[1] for r in rows), str(rows[:2]))
    rows = s.rows("select email from public.admin_list_users(%s)", [f"s3-{tag}"])
    check("search by name or e-mail works", len(rows) == 1, str(rows))
    s.user(p_admin)
    rows = s.rows("select tenant_id from public.admin_list_users(null, 1000)")
    check("platform admin sees every university", {r[0] for r in rows} >= {tum, haw})
    check("the list size is capped at 200", len(rows) <= 200)
    check("limit 1 returns 1 row", len(s.rows("select * from public.admin_list_users(null, 1)")) == 1)

    print("\n[17] Delete my account")
    gone = mk_user(f"gone-{tag}@haw-hamburg.de")
    keeper = mk_user(f"keep-{tag}@haw-hamburg.de")
    ev_g = mk_event(commercial, None, "Gone event", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=False)
    for u in (gone, keeper):
        s.user(u); s.call("select public.register_for_event(%s)", [ev_g])
    s.user(gone); s.call("select public.submit_review(%s,4,'bye')", [ev_g])
    s.anon()
    s.fails("anonymous cannot delete accounts", "select public.delete_my_account()", contains="permission denied")
    s.user(org_tum)
    _, err = s.call("select public.delete_my_account()"); check("an organizer who still owns events cannot delete the account", err is not None and "has_events" in err, str(err))
    s.postgres()
    s.c.execute("update public.profiles set role = 'student' where role = 'platform_admin' and id <> %s", [p_admin])
    s.user(p_admin)
    _, err = s.call("select public.delete_my_account()"); check("the last platform admin cannot delete themselves", err is not None and "last_admin" in err, str(err))
    s.user(gone)
    _, err = s.call("select public.delete_my_account()"); check("a student can delete their account", err is None, str(err))
    s.postgres()
    left = {t: s.scalar(f"select count(*) from public.{t} where user_id = %s", [gone]) for t in ("registrations", "tickets", "reviews")}
    check("their registrations, tickets and reviews are gone", all(v == 0 for v in left.values()), str(left))
    check("their profile and login are gone", s.scalar("select count(*) from public.profiles where id = %s", [gone]) == 0 and s.scalar("select count(*) from auth.users where id = %s", [gone]) == 0)
    check("other users were not affected", s.scalar("select count(*) from public.registrations where user_id = %s", [keeper]) == 1)
    check("their review no longer counts", s.scalar("select count(*) from public.reviews where event_id = %s", [ev_g]) == 0)

    print("\n[18] Profile photos (organizers and admins only)")
    def avatar_upload(uid, folder, name="avatar-1.png"):
        s.user(uid)
        return s.call("insert into storage.objects (bucket_id, name, owner) values ('avatars', %s, %s)",
                      [f"{folder}/{name}", uid])
    _, err = avatar_upload(org_haw, org_haw); check("a verified organizer can upload a photo into own folder", err is None, str(err))
    _, err = avatar_upload(t_admin, t_admin); check("an admin can upload a photo", err is None, str(err))
    _, err = avatar_upload(stu_tum2, stu_tum2); check("a student cannot upload a photo", err is not None, "student uploaded")
    _, err = avatar_upload(org_unverified, org_unverified); check("an UNapproved organizer cannot upload a photo", err is not None, "uploaded")
    _, err = avatar_upload(org_haw, org_tum, "avatar-2.png"); check("cannot upload a photo into someone else's folder", err is not None, "uploaded")
    s.anon()
    _, err = s.call("insert into storage.objects (bucket_id, name) values ('avatars', %s)", [f"{org_haw}/avatar-3.png"]); check("anonymous cannot upload a photo", err is not None)
    s.user(org_tum)
    s.affects_nothing("cannot delete another user's photo", "delete from storage.objects where bucket_id='avatars' and name = %s", [f"{org_haw}/avatar-1.png"])
    check("cannot list other people's photos", s.scalar("select count(*) from storage.objects where bucket_id='avatars' and name = %s", [f"{org_haw}/avatar-1.png"]) == 0)
    s.anon()
    check("anonymous cannot list the photo bucket", s.scalar("select count(*) from storage.objects where bucket_id='avatars'") == 0)
    s.user(org_haw)
    _, err = s.call("update public.profiles set avatar_path = %s where id = %s", [f"{org_haw}/avatar-1.png", org_haw]); check("organizer can set own photo path", err is None, str(err))
    for label, path in (("someone else's folder", f"{org_tum}/avatar-1.png"), ("not an avatar file name", f"{org_haw}/evil.svg"),
                        ("path traversal", f"{org_haw}/../avatar-1.png"), ("an external URL", "https://evil.example/x.png")):
        _, err = s.call("update public.profiles set avatar_path = %s where id = %s", [path, org_haw]); check(f"photo path rejected: {label}", err is not None, "accepted")
    s.user(stu_tum2)
    _, err = s.call("update public.profiles set avatar_path = %s where id = %s", [f"{stu_tum2}/avatar-1.png", stu_tum2])
    check("a student cannot set a photo path", err is not None and "avatar_not_allowed" in err, str(err))
    s.user(p_admin)
    s.call("select public.admin_set_role(%s, 'student', false)", [org_haw])
    s.postgres()
    check("losing the organizer role removes the photo", s.scalar("select avatar_path from public.profiles where id = %s", [org_haw]) is None)
    check("organizer_profiles shows the photo path column", "avatar_path" in {r[0] for r in s.rows("select column_name from information_schema.columns where table_name='organizer_profiles'")})
    b = s.rows("select public, file_size_limit, allowed_mime_types from storage.buckets where id='avatars'")[0]
    check("photo bucket: 2 MB limit, images only", b[1] is not None and b[1] <= 2_097_152 and set(b[2] or []) <= {"image/jpeg", "image/png", "image/webp"}, str(b))

    print("\n[19] Custom categories (typed by organizers)")
    s.user(org_tum)
    _, err = s.call("update public.events set categories = %s where id = %s", [["Yoga", "Tech"], ev_tum]); check("organizer can save a custom category", err is None, str(err))
    _, err = s.call("update public.events set categories = %s where id = %s", [["Café & Kultur"], ev_tum]); check("custom category with accents and & is allowed", err is None, str(err))
    for label, cats in (("31 characters", ["x" * 31]), ("1 character", ["x"]), ("empty", [""]),
                        ("leading space", [" Yoga"]), ("double space", ["Yo  ga"]), ("HTML", ["<script>"]),
                        ("newline", ["Yo\nga"]), ("duplicate (case-insensitive)", ["Yoga", "yoga"]),
                        ("4 categories", ["Yoga", "Tech", "Music", "Arts"]), ("no category", [])):
        _, err = s.call("update public.events set categories = %s::text[] where id = %s", [cats, ev_tum])
        check(f"category rejected: {label}", err is not None, "accepted")

    print("\n[20] Event contact details and organizer names")
    s.user(org_tum)
    _, err = s.call("update public.events set contact_email = 'club@tum.de', contact_phone = '+49 89 1234-567', "
                    "website_url = 'https://club.example.org/events?id=1' where id = %s", [ev_tum])
    check("organizer can save contact email, phone and website", err is None, str(err))
    for label, col, value in (("javascript: link", "website_url", "javascript:alert(1)"),
                              ("plain http link", "website_url", "http://example.org"),
                              ("data: link", "website_url", "data:text/html,hi"),
                              ("link with spaces/HTML", "website_url", "https://a.org/<script>"),
                              ("e-mail without @", "contact_email", "club.tum.de"),
                              ("e-mail with HTML", "contact_email", "<a>@b.de"),
                              ("phone with letters", "contact_phone", "call me"),
                              ("too short phone", "contact_phone", "123")):
        _, err = s.call(f"update public.events set {col} = %s where id = %s", [value, ev_tum])
        check(f"contact rejected: {label}", err is not None, "accepted")
    s.user(stu_tum)
    s.affects_nothing("a student cannot change an event's website", "update public.events set website_url = 'https://evil.example' where id = %s", [ev_tum])
    s.anon()
    names = {r[0] for r in s.rows("select id from public.organizer_profiles")}
    check("anyone can see organizer names (for the feed)", org_tum in names)
    check("organizer list shows platform admins who publish", p_admin in names)
    check("organizer list still has no students", stu_tum not in names)
    op_cols = {r[0] for r in s.rows("select column_name from information_schema.columns where table_name='organizer_profiles'")}
    check("organizer_profiles has the organization name column", "organization_name" in op_cols)
    check("organizer list does not reveal roles (who is admin) or universities", not op_cols & {"role", "tenant_id"}, str(op_cols))

    print("\n[21] Own events and organizer verification")
    s.user(org_tum)
    _, err = s.call("select public.register_for_event(%s)", [ev_tum]); check("an organizer cannot register for their own event", err is not None and "own_event" in err, str(err))
    s.user(stu_tum)
    _, err = s.call("select public.register_for_event(%s)", [ev_tum]); check("a student can still register for that event", err is None, str(err))
    vf = mk_user(f"vf-{tag}@haw-hamburg.de")
    vf2 = mk_user(f"vf2-{tag}@haw-hamburg.de")
    def doc_upload(uid, folder, name, mime="application/pdf"):
        s.user(uid)
        return s.call("insert into storage.objects (bucket_id, name, owner, metadata) values ('organizer-docs', %s, %s, %s)",
                      [f"{folder}/{name}", uid, json.dumps({"mimetype": mime})])
    _, err = doc_upload(vf, vf, "doc-1.pdf"); check("an applicant can upload a document into own folder", err is None, str(err))
    _, err = doc_upload(vf, vf, "doc-2.jpg"); check("an applicant can upload a second document", err is None, str(err))
    _, err = doc_upload(vf, vf2, "doc-1.pdf"); check("cannot upload a document into someone else's folder", err is not None, "uploaded")
    _, err = doc_upload(vf, vf, "evil.html"); check("document names other than doc-N.pdf/jpg/png are refused", err is not None, "uploaded")
    _, err = doc_upload(org_tum, org_tum, "doc-1.pdf"); check("an organizer (not applying) cannot upload documents", err is not None, "uploaded")
    s.anon()
    _, err = s.call("insert into storage.objects (bucket_id, name) values ('organizer-docs', %s)", [f"{vf}/doc-9.pdf"]); check("anonymous cannot upload documents", err is not None)
    for i in range(3, 9):
        doc_upload(vf2, vf2, f"doc-{i}.pdf")
    _, err = doc_upload(vf2, vf2, "doc-9.pdf"); check("at most 6 documents per person", err is not None, "7th upload accepted")
    s.user(vf)
    good = [f"{vf}/doc-1.pdf", f"{vf}/doc-2.jpg"]
    q = "select public.request_organizer_access('organizer', 'HAW Chess', 'Hi', %s, %s, %s, %s::text[])"
    for label, args in (("no phone", ["Chair", "", None, []]), ("phone with letters", ["Chair", "call me", None, []]),
                        ("no position", ["", "+49 89 123456", None, []]),
                        ("javascript: website", ["Chair", "+49 89 123456", "javascript:alert(1)", []]),
                        ("someone else's document", ["Chair", "+49 89 123456", None, [f"{vf2}/doc-3.pdf"]]),
                        ("a document that was never uploaded", ["Chair", "+49 89 123456", None, [f"{vf}/doc-7.pdf"]]),
                        ("a document path with traversal", ["Chair", "+49 89 123456", None, [f"{vf}/../doc-1.pdf"]]),
                        ("4 documents", ["Chair", "+49 89 123456", None, good + [f"{vf}/doc-3.pdf", f"{vf}/doc-4.pdf"]]),
                        ("the same document twice", ["Chair", "+49 89 123456", None, [good[0], good[0]]])):
        _, err = s.call(q, args); check(f"application refused: {label}", err is not None, "accepted")
    _, err = s.call(q, ["Chair of the chess club", "+49 89 123456", "https://chess.example.org", good])
    check("an application with phone, website and 2 documents is accepted", err is None, str(err))
    s.user(vf2)
    check("another student cannot see the applicant's documents",
          s.scalar("select count(*) from storage.objects where bucket_id='organizer-docs' and name = any(%s)", [good]) == 0)
    s.affects_nothing("another student cannot delete the applicant's documents",
                      "delete from storage.objects where bucket_id='organizer-docs' and name = %s", [good[0]])
    s.user(t_admin)
    check("the university admin can see the documents", s.scalar("select count(*) from storage.objects where bucket_id='organizer-docs' and name = any(%s)", [good]) == 2)
    row = s.rows("select phone, applicant_position, website_url from public.organizer_requests where user_id = %s", [vf])
    check("the admin sees phone, position and website", row and row[0] == ("+49 89 123456", "Chair of the chess club", "https://chess.example.org"), str(row))
    s.affects_nothing("documents of a PENDING request cannot be deleted by the admin",
                      "delete from storage.objects where bucket_id='organizer-docs' and name = %s", [good[0]])
    s.user(rq_haw)
    check("an organizer of the same university cannot see the documents",
          s.scalar("select count(*) from storage.objects where bucket_id='organizer-docs' and name = any(%s)", [good]) == 0)
    s.postgres()
    b = s.rows("select public, file_size_limit, allowed_mime_types from storage.buckets where id='organizer-docs'")[0]
    check("document bucket is PRIVATE, 5 MB, PDF/JPG/PNG only",
          b[0] is False and b[1] is not None and b[1] <= 5_242_880 and set(b[2] or []) <= {"application/pdf", "image/jpeg", "image/png"}, str(b))

    print("\n[22] Favourites")
    fav1 = mk_user(f"fav1-{tag}@tum.de")
    fav2 = mk_user(f"fav2-{tag}@tum.de")
    ev_fav = mk_event(org_tum, tum, "Fav TUM")
    ev_fav_haw = mk_event(rq_haw, haw, "Fav HAW only")
    s.user(fav1)
    _, err = s.call("insert into public.favorites (event_id) values (%s)", [ev_fav]); check("a student can save an event", err is None, str(err))
    _, err = s.call("insert into public.favorites (event_id) values (%s)", [ev_fav]); check("saving twice is refused", err is not None, "accepted")
    _, err = s.call("insert into public.favorites (event_id) values (%s)", [ev_fav_haw]); check("cannot save another university's event", err is not None, "accepted")
    _, err = s.call("insert into public.favorites (user_id, event_id) values (%s, %s)", [fav2, ev_pub]); check("cannot save an event for someone else", err is not None, "accepted")
    s.fails("cannot change a saved event", "update public.favorites set event_id = %s", [ev_pub], contains="permission denied")
    s.user(fav2)
    check("other users do not see my saved events", s.scalar("select count(*) from public.favorites") == 0)
    s.affects_nothing("other users cannot delete my saved events", "delete from public.favorites where event_id = %s", [ev_fav])
    s.anon()
    s.fails("anonymous cannot read saved events", "select * from public.favorites", contains="permission denied")
    s.user(fav1)
    _, err = s.call("delete from public.favorites where event_id = %s", [ev_fav]); check("a student can un-save an event", err is None and s.scalar("select count(*) from public.favorites") == 0, str(err))

    print("\n[23] Reporting and moderation")
    rp1 = mk_user(f"rp1-{tag}@haw-hamburg.de")
    rp2 = mk_user(f"rp2-{tag}@haw-hamburg.de")
    rp_tum = mk_user(f"rp3-{tag}@tum.de")
    ev_rep = mk_event(rq_haw, haw, "Report me HAW")
    ev_rep2 = mk_event(rq_haw, haw, "Report me too")
    ev_rep_pub = mk_event(commercial, None, "Public to report")
    s.user(rp1)
    _, err = s.call("select public.report_event(%s, 'spam', 'Looks like an ad')", [ev_rep]); check("a student can report an event", err is None, str(err))
    _, err = s.call("select public.report_event(%s, 'spam', '')", [ev_rep]); check("the same person cannot report the same event twice", err is not None and "already_reported" in err, str(err))
    _, err = s.call("select public.report_event(%s, 'nonsense', '')", [ev_rep2]); check("unknown report reasons are refused", err is not None, "accepted")
    _, err = s.call("select public.report_event(%s, 'other', %s)", [ev_rep2, "x" * 501]); check("report details are limited to 500 characters", err is not None, "accepted")
    _, err = s.call("select public.report_event(%s, 'scam', '')", [ev_fav]); check("cannot report another university's event", err is not None and "event_not_available" in err, str(err))
    s.fails("cannot insert reports directly", "insert into public.event_reports (event_id, reporter_id, reason) values (%s, %s, 'spam')", [ev_rep, rp1], contains="permission denied")
    s.fails("cannot change reports directly", "update public.event_reports set status = 'dismissed'", contains="permission denied")
    s.user(rq_haw)
    _, err = s.call("select public.report_event(%s, 'spam', '')", [ev_rep]); check("an organizer cannot report their own event", err is not None and "own_event" in err, str(err))
    check("the organizer cannot see reports about their event", s.scalar("select count(*) from public.event_reports") == 0)
    s.user(rp2)
    check("other students cannot see someone's report", s.scalar("select count(*) from public.event_reports") == 0)
    s.call("select public.report_event(%s, 'misleading', '')", [ev_rep])
    s.call("select public.report_event(%s, 'other', 'Rude text')", [ev_rep_pub])
    s.anon()
    s.fails("anonymous cannot report", "select public.report_event(%s, 'spam', '')", [ev_rep_pub], contains="permission denied")
    s.fails("anonymous cannot read reports", "select * from public.event_reports", contains="permission denied")
    s.user(rp_tum)
    for i in range(10):
        e = mk_event(commercial, None, f"Flood {i}")
        s.user(rp_tum); s.call("select public.report_event(%s, 'spam', '')", [e])
    _, err = s.call("select public.report_event(%s, 'spam', '')", [ev_rep_pub]); check("at most 10 reports per person per day", err is not None and "too_many_reports" in err, str(err))

    s.postgres()
    rid = lambda uid, ev: s.scalar("select id from public.event_reports where reporter_id = %s and event_id = %s", [uid, ev])
    r1, r2, r_pub = rid(rp1, ev_rep), rid(rp2, ev_rep), rid(rp2, ev_rep_pub)
    s.user(t_admin)
    seen = {r[0] for r in s.rows("select id from public.event_reports")}
    check("the university admin sees reports about THEIR university's events only", r1 in seen and r2 in seen and r_pub not in seen, str(len(seen)))
    for who, label in ((rp1, "a student"), (rq_haw, "the event's organizer"), (org_tum, "another organizer")):
        s.user(who)
        _, err = s.call("select public.resolve_report(%s, true)", [r1]); check(f"{label} cannot resolve reports", err is not None and "not_authorized" in err, str(err))
    s.user(t_admin)
    _, err = s.call("select public.resolve_report(%s, true)", [r_pub]); check("a university admin cannot moderate public events", err is not None and "not_authorized" in err, str(err))
    _, err = s.call("select public.resolve_report(%s, false)", [r2]); check("the university admin can dismiss a report", err is None, str(err))
    _, err = s.call("select public.resolve_report(%s, false)", [r2]); check("a report cannot be resolved twice", err is not None and "already_reviewed" in err, str(err))
    _, err = s.call("select public.resolve_report(%s, true, 'Advertising')", [r1]); check("the university admin can remove the reported event", err is None, str(err))
    s.postgres()
    row = s.rows("select status::text, moderated_at is not null, moderation_note from public.events where id = %s", [ev_rep])[0]
    check("a removed event is cancelled and marked as moderated", row == ("cancelled", True, "Advertising"), str(row))
    check("its open reports are closed", s.scalar("select count(*) from public.event_reports where event_id = %s and status = 'open'", [ev_rep]) == 0)
    s.user(rq_haw)
    _, err = s.call("update public.events set status = 'published' where id = %s", [ev_rep]); check("the organizer cannot bring a removed event back", err is not None, "re-published")
    s.affects_nothing("the organizer cannot clear the moderation mark", "update public.events set moderated_at = null where id = %s", [ev_rep])
    _, err = s.call("insert into public.events (organizer_id,tenant_id,title,location,starts_at,ends_at,status,moderated_at,moderation_note) "
                    "values (%s,%s,'Fake','Hall',now()+interval '1 d',now()+interval '2 d','published',now(),'fake') returning moderated_at", [rq_haw, haw])
    s.postgres()
    check("a new event can never arrive with a moderation mark",
          s.scalar("select count(*) from public.events where title = 'Fake' and organizer_id = %s and moderated_at is not null", [rq_haw]) == 0)
    s.user(p_admin)
    _, err = s.call("select public.resolve_report(%s, true)", [r_pub]); check("the platform admin can moderate public events", err is None, str(err))

    print("\n[24] Notifications and push devices")
    n1, n2, n3 = (mk_user(f"n{i}-{tag}@tum.de") for i in (1, 2, 3))
    def notes(uid, kind=None):
        s.postgres()
        q = "select count(*) from public.notifications where user_id = %s" + (" and kind = %s" if kind else "")
        return s.scalar(q, [uid, kind] if kind else [uid])
    ev_n = mk_event(org_tum, tum, "Notify me", capacity=1)
    for u in (n1, n2):
        s.user(u); s.call("select public.register_for_event(%s)", [ev_n])
    s.user(n1); s.call("select public.cancel_registration(%s)", [ev_n])
    check("a waitlisted student is told when they get a spot", notes(n2, "waitlist_promoted") == 1)
    s.user(org_tum); s.call("update public.events set location = 'New hall' where id = %s", [ev_n])
    check("registered students are told when the place changes", notes(n2, "event_changed") == 1)
    check("students who cancelled are not told", notes(n1, "event_changed") == 0)
    s.user(org_tum); s.call("update public.events set starts_at = starts_at + interval '1 hour' where id = %s", [ev_n])
    check("quick repeated edits send one message, not one per save", notes(n2, "event_changed") == 1)
    s.user(org_tum); s.call("update public.events set description = 'typo fixed' where id = %s", [ev_n])
    check("editing only the description sends nothing", notes(n2) == 2)
    s.user(n3)
    _, err = s.call("update public.profiles set notify_updates = false where id = %s", [n3]); check("a user can turn off event updates", err is None, str(err))
    s.affects_nothing("a user cannot change someone else's notification settings", "update public.profiles set notify_updates = false where id = %s", [n2])
    s.call("select public.register_for_event(%s)", [ev_n])  # waitlisted
    s.user(org_tum); s.call("update public.events set status = 'cancelled' where id = %s", [ev_n])
    check("registered students are told when an event is cancelled", notes(n2, "event_cancelled") == 1)
    check("students who turned off updates are not told", notes(n3) == 0)
    check("the organizer gets no message about their own cancellation", notes(org_tum, "event_cancelled") == 0)
    check("an organizer is told when their event is removed after a report", notes(rq_haw, "event_removed") >= 1)
    check("an applicant is told when their application is approved", notes(rq_haw, "request_approved") >= 1)
    check("an applicant is told when their application is rejected", notes(rq_pub, "request_rejected") >= 1)

    n4, n5, n6 = (mk_user(f"n{i}-{tag}@tum.de") for i in (4, 5, 6))
    ev_soon = mk_event(org_tum, tum, "Remind me", start="now() + interval '5 hours'", end="now() + interval '7 hours'")
    ev_later = mk_event(org_tum, tum, "Not yet", start="now() + interval '3 days'", end="now() + interval '3 days 2 hours'")
    for u in (n4, n5, n6):
        for e in (ev_soon, ev_later):
            s.user(u); s.call("select public.register_for_event(%s)", [e])
    s.postgres()
    c.execute("update public.registrations set created_at = now() - interval '2 hours' where user_id = any(%s)", [[n4, n6]])
    c.execute("update public.profiles set notify_reminders = false where id = %s", [n6])
    s.scalar("select public.queue_event_reminders()")
    check("registered students get a reminder in the 24 hours before an event", notes(n4, "reminder") == 1)
    check("no reminder right after registering", notes(n5, "reminder") == 0)
    check("no reminder when reminders are turned off", notes(n6, "reminder") == 0)
    check("no reminder for events more than a day away", s.scalar("select count(*) from public.notifications where event_id = %s", [ev_later]) == 0)
    s.scalar("select public.queue_event_reminders()")
    check("each event is reminded only once", notes(n4, "reminder") == 1)

    s.user(n3)
    check("users see only their own notifications", s.scalar("select count(*) from public.notifications") == 0)
    s.user(n2)
    check("a user sees their own notifications", s.scalar("select count(*) from public.notifications") == notes(n2))
    s.user(n2)
    s.fails("users cannot create notifications", "insert into public.notifications (user_id, kind) values (%s, 'request_approved')", [n2], contains="permission denied")
    s.fails("users cannot change what a notification says", "update public.notifications set kind = 'reminder'", contains="permission denied")
    s.fails("users cannot change the push state", "update public.notifications set push_state = 'pending'", contains="permission denied")
    _, err = s.call("update public.notifications set read_at = now() where user_id = %s", [n2]); check("a user can mark their notifications as read", err is None, str(err))
    s.user(n1)
    s.affects_nothing("cannot mark someone else's notifications as read", "update public.notifications set read_at = now() where user_id = %s", [n2])
    s.affects_nothing("cannot delete someone else's notifications", "delete from public.notifications where user_id = %s", [n2])
    s.anon()
    s.fails("anonymous cannot read notifications", "select * from public.notifications", contains="permission denied")

    tok = f"fcm-{tag}-" + "x" * 40
    s.user(n1)
    _, err = s.call("select public.register_push_token(%s, 'android')", [tok]); check("a user can register their phone for push", err is None, str(err))
    s.fails("users cannot read the device list", "select * from public.push_tokens", contains="permission denied")
    s.fails("users cannot write the device list directly", "insert into public.push_tokens (token, user_id, platform) values (%s, %s, 'web')", [tok + "y", n2], contains="permission denied")
    _, err = s.call("select public.register_push_token(%s, 'fridge')", [tok + "2"]); check("unknown device types are refused", err is not None, "accepted")
    _, err = s.call("select public.register_push_token('short', 'web')"); check("malformed device tokens are refused", err is not None, "accepted")
    s.user(n2); s.call("select public.unregister_push_token(%s)", [tok])
    s.postgres()
    check("a user cannot remove someone else's device", s.scalar("select user_id from public.push_tokens where token = %s", [tok]) == n1)
    s.user(n2); s.call("select public.register_push_token(%s, 'android')", [tok])
    s.postgres()
    check("a device belongs to whoever signed in on it last", s.scalar("select user_id from public.push_tokens where token = %s", [tok]) == n2)
    for i in range(12):
        s.user(n1); s.call("select public.register_push_token(%s, 'web')", [f"{tok}-{i:02d}"])
    s.postgres()
    check("at most 10 devices per account", s.scalar("select count(*) from public.push_tokens where user_id = %s", [n1]) == 10)
    s.anon()
    s.fails("anonymous cannot register a device", "select public.register_push_token(%s, 'web')", [tok + "z"], contains="permission denied")
    for fn, q, args in (("claim_push_batch", "select * from public.claim_push_batch(10)", None),
                        ("finish_push", "select public.finish_push(%s::bigint[], 'sent')", [[1]]),
                        ("push_targets", "select * from public.push_targets(%s::uuid[])", [[n2]]),
                        ("forget_push_tokens", "select public.forget_push_tokens(%s::text[])", [[tok]]),
                        ("push_secret_ok", "select public.push_secret_ok('x')", None),
                        ("kick_push", "select public.kick_push()", None),
                        ("retry_push", "select public.retry_push()", None),
                        ("queue_event_reminders", "select public.queue_event_reminders()", None),
                        ("notify_event_attendees", "select public.notify_event_attendees(%s, 'reminder', null)", [ev_soon])):
        s.user(n1)
        s.fails(f"a user cannot call the server-only function {fn}", q, args, contains="permission denied")
    s.user(n1)
    s.fails("users cannot read Vault secrets", "select * from vault.decrypted_secrets", contains="permission denied")
    s.postgres()
    c.execute("set local role service_role")
    claimed = s.rows("select id, user_id, kind from public.claim_push_batch(500)")
    mine = [r for r in claimed if r[1] == n2]
    check("the push server can claim pending notifications", len(mine) == 3, str(len(mine)))
    c.execute("set local role service_role")
    check("claimed notifications are not handed out twice", s.rows("select id from public.claim_push_batch(500)") == [])
    c.execute("set local role service_role")
    s.c.execute("select public.finish_push(%s::bigint[], 'sent')", [[r[0] for r in mine]])
    s.postgres()
    check("sent notifications are marked as sent", s.scalar("select count(*) from public.notifications where user_id = %s and push_state <> 'sent'", [n2]) == 0)
    s.postgres()
    c.execute("set local role service_role")
    targets = s.rows("select user_id, token, platform, locale from public.push_targets(%s::uuid[])", [[n2]])
    check("the push server finds the user's devices and language", targets == [(n2, tok, "android", "en")], str(targets))
    s.postgres()

    print("\n[25] 'Are you still coming?' checks and organizer statistics")
    a1, a2, a3, w1, late_reg = (mk_user(f"a{i}-{tag}@tum.de") for i in range(1, 6))
    in2d = dict(start="now() + interval '2 days'", end="now() + interval '2 days 2 hours'")
    ev_rel = mk_event(org_tum, tum, "Release on", capacity=2, **in2d)
    ev_keep = mk_event(org_tum, tum, "Release off", capacity=1, **in2d)
    ev_far = mk_event(org_tum, tum, "Far away", start="now() + interval '5 days'", end="now() + interval '5 days 2 hours'")
    s.user(org_tum)
    _, err = s.call("update public.events set release_unconfirmed = true where id = %s", [ev_rel])
    check("an organizer can switch on 'free unconfirmed seats' for their event", err is None, str(err))
    s.user(org_haw)
    s.affects_nothing("another organizer cannot change that setting", "update public.events set release_unconfirmed = false where id = %s", [ev_rel])
    for u, evs in ((a1, (ev_rel, ev_far)), (a2, (ev_rel, ev_keep)), (w1, (ev_rel, ev_keep)), (late_reg, (ev_far,))):
        for e in evs:
            s.user(u); s.call("select public.register_for_event(%s)", [e])
    s.postgres()
    c.execute("update public.registrations set created_at = now() - interval '1 day' where user_id = any(%s)", [[a1, a2, w1]])
    s.user(org_tum); s.call("select public.register_for_event(%s)", [ev_far])
    s.user(late_reg); s.call("select public.register_for_event(%s)", [ev_rel])  # waitlisted, registered just now
    s.postgres()
    s.scalar("select public.process_attendance_checks()")
    check("seat holders are asked about 3 days before the event", notes(a1, "confirm_attendance") == 1 and notes(a2, "confirm_attendance") == 2)
    check("people on the waitlist are not asked", s.scalar("select confirm_asked_at from public.registrations where user_id = %s and event_id = %s", [w1, ev_rel]) is None)
    check("events further away are not asked yet", s.scalar("select count(*) from public.notifications where event_id = %s and kind = 'confirm_attendance'", [ev_far]) == 0)
    s.scalar("select public.process_attendance_checks()")
    check("each person is asked only once", notes(a1, "confirm_attendance") == 1)

    s.user(a1)
    at, err = s.call("select public.confirm_attendance(%s)", [ev_rel])
    check("a student can answer 'yes, I'm coming'", err is None and at is not None, str(err))
    s.fails("a student cannot set the confirmation directly", "update public.registrations set confirmed_at = now() where user_id = %s", [a1], contains="permission denied")
    s.user(stu_pub)
    _, err = s.call("select public.confirm_attendance(%s)", [ev_rel]); check("confirming without a seat is refused", err is not None and "not_registered" in err, str(err))
    s.user(w1)
    _, err = s.call("select public.confirm_attendance(%s)", [ev_rel]); check("people on the waitlist cannot confirm a seat they do not have", err is not None, "accepted")
    s.anon()
    s.fails("anonymous cannot confirm", "select public.confirm_attendance(%s)", [ev_rel], contains="permission denied")
    s.user(a1)
    s.fails("a user cannot run the attendance job", "select public.process_attendance_checks()", contains="permission denied")

    # 20 hours before the start, nobody answered for 13 hours.
    s.postgres()
    c.execute("update public.events set starts_at = now() + interval '20 hours', ends_at = now() + interval '22 hours' where id = any(%s)", [[ev_rel, ev_keep]])
    c.execute("update public.registrations set confirm_asked_at = now() - interval '13 hours' where confirm_asked_at is not null")
    s.scalar("select public.process_attendance_checks()")
    status = lambda u, e: s.scalar("select status::text from public.registrations where user_id = %s and event_id = %s", [u, e])
    check("an unconfirmed seat is freed when the organizer chose that and people are waiting", status(a2, ev_rel) == "cancelled")
    check("...and the student is told why", notes(a2, "seat_released") == 1)
    check("...and the first person waiting gets the seat and a ticket", status(w1, ev_rel) == "registered" and code_of(w1, ev_rel) is not None)
    check("...with a voided ticket for the freed seat", s.scalar("select voided_at is not null from public.tickets where user_id = %s and event_id = %s", [a2, ev_rel]))
    check("confirmed seats are never freed", status(a1, ev_rel) == "registered")
    check("only as many seats are freed as people are waiting", status(late_reg, ev_rel) == "waitlisted"
          and s.scalar("select count(*) from public.registrations where event_id = %s and released_at is not null", [ev_rel]) == 1)
    check("events without the setting keep unconfirmed seats", status(a2, ev_keep) == "registered" and status(w1, ev_keep) == "waitlisted")

    a4 = mk_user(f"a6-{tag}@tum.de")
    ev_nowait = mk_event(org_tum, tum, "Nobody waiting", capacity=5, **in2d)
    s.postgres(); c.execute("update public.events set release_unconfirmed = true where id = %s", [ev_nowait])
    s.user(a4); s.call("select public.register_for_event(%s)", [ev_nowait])
    s.postgres()
    c.execute("update public.registrations set created_at = now() - interval '1 day' where user_id = %s", [a4])
    s.scalar("select public.process_attendance_checks()")
    c.execute("update public.events set starts_at = now() + interval '20 hours', ends_at = now() + interval '22 hours' where id = %s", [ev_nowait])
    c.execute("update public.registrations set confirm_asked_at = now() - interval '13 hours' where user_id = %s", [a4])
    s.scalar("select public.process_attendance_checks()")
    check("no seat is freed when nobody is waiting", status(a4, ev_nowait) == "registered")

    s.user(org_tum)
    row = s.rows("select registered, waitlisted, confirmed, cancelled, released, requires_qr, release_unconfirmed from public.event_stats where event_id = %s", [ev_rel])
    check("organizer statistics show confirmed, cancelled and freed seats", row == [(2, 1, 1, 1, 1, True, True)], str(row))
    ins, err = s.call("select public.event_insights(%s)", [ev_rel])
    check("an organizer gets the sign-ups per day and star counts of their event",
          err is None and sum(d["count"] for d in ins["signups"]) == 4 and ins["stars"] == [0, 0, 0, 0, 0] and ins["asked"] >= 2, str(err or ins))
    for who, uid in (("a student", a1), ("another organizer", org_haw)):
        s.user(uid)
        _, err = s.call("select public.event_insights(%s)", [ev_rel])
        check(f"{who} cannot read an event's statistics", err is not None and "not_authorized" in err, str(err))
    s.anon()
    s.fails("anonymous cannot read event statistics", "select public.event_insights(%s)", [ev_rel], contains="permission denied")
    s.postgres()
    s.user(a2); s.call("select public.register_for_event(%s)", [ev_rel])
    s.postgres()
    check("registering again starts a fresh confirmation", s.scalar(
        "select released_at is null and confirm_asked_at is null and confirmed_at is null from public.registrations where user_id = %s and event_id = %s", [a2, ev_rel]))

    print("\n[13] Privileges audit (what is exposed at all)")
    s.postgres()
    allowed_exec = {
        "anon": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count",
                 "categories_ok"},
        "authenticated": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count",
                          "register_for_event", "cancel_registration", "check_in_ticket", "submit_review", "admin_set_role",
                          "is_verified_publisher", "user_tenant", "request_organizer_access",
                          "review_organizer_request", "admin_list_users", "delete_my_account",
                          "may_have_avatar", "can_have_avatar", "categories_ok", "my_organizer_doc_count",
                          "can_moderate_event", "report_event", "resolve_report",
                          "register_push_token", "unregister_push_token", "confirm_attendance", "event_insights"},
    }
    funcs = s.rows("select p.proname, has_function_privilege('anon', p.oid, 'execute'), has_function_privilege('authenticated', p.oid, 'execute'), "
                   "p.prosecdef, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'")
    for name, a, au, secdef, cfg in funcs:
        check(f"function {name}: anon access is exactly as intended", a == (name in allowed_exec["anon"]))
        check(f"function {name}: signed-in access is exactly as intended", au == (name in allowed_exec["authenticated"]))
        check(f"function {name}: has a fixed search_path", bool(cfg) and any("search_path" in x for x in cfg))
    expected = {  # table -> (anon privileges, authenticated privileges)
        "tenants": (set(["SELECT"]), set(["SELECT", "INSERT", "UPDATE", "DELETE"])),
        "tenant_domains": (set(), set(["SELECT", "INSERT", "UPDATE", "DELETE"])),
        "profiles": (set(), set(["SELECT"])),
        "events": (set(["SELECT"]), set(["SELECT", "INSERT", "DELETE"])),
        "registrations": (set(), set(["SELECT"])), "tickets": (set(), set(["SELECT"])), "scan_log": (set(), set(["SELECT"])),
        "reviews": (set(["SELECT"]), set(["SELECT"])),
        "event_rating_stats": (set(["SELECT"]), set(["SELECT"])), "event_stats": (set(), set(["SELECT"])),
        "organizer_profiles": (set(["SELECT"]), set(["SELECT"])),
        "organizer_requests": (set(), set(["SELECT"])),
        "favorites": (set(), set(["SELECT", "INSERT", "DELETE"])),
        "event_reports": (set(), set(["SELECT"])),
        "notifications": (set(), set(["SELECT", "DELETE"])),
    }
    grants = {}
    for table, grantee, priv in s.rows("select table_name, grantee, privilege_type from information_schema.role_table_grants "
                                       "where table_schema = 'public' and grantee in ('anon','authenticated')"):
        grants.setdefault((table, grantee), set()).add(priv)
    for table, (a, au) in expected.items():
        check(f"table {table}: anon privileges = {sorted(a) or 'none'}", grants.get((table, "anon"), set()) == a, str(grants.get((table, "anon"))))
        check(f"table {table}: signed-in privileges = {sorted(au)}", grants.get((table, "authenticated"), set()) == au, str(grants.get((table, "authenticated"))))
    for t in {x for x, _ in grants} - set(expected):
        check(f"unexpected exposed object {t}", False)
    s.postgres()
    for kind, acl in s.rows("select defaclobjtype, defaclacl::text from pg_default_acl where defaclrole = 'postgres'::regrole "
                            "and defaclnamespace = 'public'::regnamespace"):
        open_to = [g for g in ("anon=", "authenticated=") if g in acl] + (["everyone"] if acl.startswith("{=") or ",=" in acl else [])
        check(f"new {dict(r='tables', S='sequences', f='functions').get(kind, kind)} are not public by default", not open_to, acl)
    unprotected = s.rows("select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity")
    check("every public table has Row Level Security on", not unprotected, str(unprotected))
    views = s.rows("select c.relname, c.reloptions from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v'")
    for name, opts in views:
        invoker = any("security_invoker=true" in o for o in (opts or []))
        check(f"view {name}: " + ("runs with the caller's permissions" if name != "organizer_profiles" else "(intentionally definer: exposes only verified organizers)"),
              invoker or name == "organizer_profiles")

    if real_tickets == 0:
        s.postgres()
        s.c.execute("select setval(pg_get_serial_sequence('public.tickets','ticket_number'), 1, false)")


if __name__ == "__main__":
    sys.exit(main())

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

    # Pen test 2026-11-11 (S1): a university admin must not touch other admins.
    root_haw = mk_user(f"root2-{tag}@haw-hamburg.de"); promote(root_haw, "platform_admin")
    t_admin_b = mk_user(f"admin2-{tag}@haw-hamburg.de"); promote(t_admin_b, "tenant_admin")
    biz_haw = mk_user(f"biz2-{tag}@haw-hamburg.de"); promote(biz_haw, "commercial_planner")
    org_x = mk_user(f"orgx-{tag}@haw-hamburg.de"); promote(org_x, "organizer")

    def role_of(uid):
        s.postgres()
        return s.scalar("select role::text from public.profiles where id = %s", [uid])

    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [root_haw])
    check("tenant admin cannot demote a platform admin of the same university", err is not None and "not_authorized" in err and role_of(root_haw) == "platform_admin", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'organizer',true)", [root_haw])
    check("tenant admin cannot turn a platform admin into an organizer", err is not None and role_of(root_haw) == "platform_admin", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [t_admin_b])
    check("tenant admin cannot demote another tenant admin", err is not None and "not_authorized" in err and role_of(t_admin_b) == "tenant_admin", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [biz_haw])
    check("tenant admin cannot demote a commercial planner", err is not None and role_of(biz_haw) == "commercial_planner", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [t_admin])
    check("tenant admin cannot change their own role", err is not None and role_of(t_admin) == "tenant_admin", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_delete_user(%s, true)", [root_haw])
    check("so a tenant admin can never remove a platform admin", err is not None and role_of(root_haw) == "platform_admin", str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [org_x])
    check("tenant admin can still take organizer rights away", err is None and role_of(org_x) == "student", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [t_admin_b])
    check("platform admin can still demote a tenant admin", err is None and role_of(t_admin_b) == "student", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [root_haw])
    check("platform admin can demote another platform admin while one remains", err is None and role_of(root_haw) == "student", str(err))

    # Pen test 2026-11-11 (S4): the platform must always keep one platform admin.
    s.postgres()
    others = [r[0] for r in s.rows("select id from public.profiles where role = 'platform_admin' and id <> %s", [p_admin])]
    s.c.execute("update public.profiles set role = 'student' where id = any(%s)", [others])
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [p_admin])
    check("the last platform admin cannot demote themselves", err is not None and "last_admin" in err and role_of(p_admin) == "platform_admin", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'platform_admin',true)", [p_admin])
    check("the last platform admin can still re-save their own role", err is None, str(err))
    s.postgres()
    s.c.execute("update public.profiles set role = 'platform_admin' where id = any(%s)", [others])
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

    print("\n[26] Seat counts for the feed")
    s.anon()
    rows = dict(s.rows("select event_id, registered from public.event_seat_counts(%s::uuid[])", [[ev_pub, ev_tum, ev_draft]]))
    check("visitors get seat counts of public events", ev_pub in rows)
    check("visitors get no counts for university events or drafts", ev_tum not in rows and ev_draft not in rows, str(rows))
    s.user(stu_tum)
    rows = dict(s.rows("select event_id, registered from public.event_seat_counts(%s::uuid[])", [[ev_tum, ev_haw]]))
    check("students get counts for their own university's events only", ev_tum in rows and ev_haw not in rows, str(rows))
    check("the count matches the single-event count", rows.get(ev_tum) == s.scalar("select public.event_registered_count(%s)", [ev_tum]))

    print("\n[27] Unconfirmed sign-ups expire; admins remove users")
    s.postgres()
    stale = mk_user(f"stale-{tag}@haw-hamburg.de", confirmed=False)
    fresh = mk_user(f"fresh-{tag}@haw-hamburg.de", confirmed=False)
    resent = mk_user(f"resent-{tag}@haw-hamburg.de", confirmed=False)
    s.c.execute("update auth.users set created_at = now() - interval '30 minutes' where id in (%s, %s)", [stale, resent])
    s.c.execute("update auth.users set confirmation_sent_at = now() - interval '5 minutes' where id = %s", [resent])
    s.user(stu_haw)
    _, err = s.call("select public.purge_unconfirmed_signups()"); check("a student cannot run the sign-up clean-up", err is not None and "permission denied" in err, str(err))
    s.postgres()
    s.c.execute("select public.purge_unconfirmed_signups()")
    alive = lambda u: s.scalar("select count(*) from auth.users where id = %s", [u]) == 1
    check("a sign-up without the code is removed after 20 minutes", not alive(stale))
    check("its profile is removed too", s.scalar("select count(*) from public.profiles where id = %s", [stale]) == 0)
    check("a sign-up from a few minutes ago stays", alive(fresh))
    check("asking for a new code restarts the 20 minutes", alive(resent))
    check("confirmed accounts are never touched", alive(stu_haw) and alive(stu_tum))
    check("the clean-up runs every 5 minutes", s.scalar("select count(*) from cron.job where jobname = 'unihub-purge-unconfirmed' and schedule = '*/5 * * * *'") == 1)

    bad = mk_user(f"bad-{tag}@haw-hamburg.de"); promote(bad, "organizer")
    fan = mk_user(f"fan-{tag}@haw-hamburg.de")
    ev_bad = mk_event(bad, haw, "Bad upcoming")
    ev_bad_old = mk_event(bad, haw, "Bad past", start="now() - interval '3 days'", end="now() - interval '3 days' + interval '2 hours'")
    s.user(fan); s.call("select public.register_for_event(%s)", [ev_bad])
    s.user(bad); s.call("select public.register_for_event(%s)", [ev_haw])
    victim = mk_user(f"victim-{tag}@tum.de")
    s.anon()
    s.fails("anonymous cannot remove users", "select public.admin_delete_user(%s)", [bad], contains="permission denied")
    s.user(stu_haw)
    _, err = s.call("select public.admin_delete_user(%s)", [bad]); check("a student cannot remove users", err is not None and "not_authorized" in err, str(err))
    s.user(org_haw)
    _, err = s.call("select public.admin_delete_user(%s)", [fan]); check("an organizer cannot remove users", err is not None and "not_authorized" in err, str(err))
    s.user(t_admin)
    _, err = s.call("select public.admin_delete_user(%s)", [victim]); check("a university admin cannot remove another university's user", err is not None and "not_authorized" in err, str(err))
    _, err = s.call("select public.admin_delete_user(%s)", [commercial]); check("a university admin cannot remove a commercial planner", err is not None and "not_authorized" in err, str(err))
    _, err = s.call("select public.admin_delete_user(%s)", [p_admin]); check("admins cannot be removed before being demoted", err is not None and "demote_first" in err, str(err))
    _, err = s.call("select public.admin_delete_user(%s)", [t_admin]); check("an admin cannot remove themselves here", err is not None and "cannot_remove_self" in err, str(err))
    row = s.rows("select email_confirmed, event_count from public.admin_list_users(%s)", [f"bad-{tag}"])
    check("the admin list shows confirmation and event count", row == [(True, 2)], str(row))
    r, err = s.call("select public.admin_delete_user(%s, true)", [bad]); check("a university admin removes a user of their university", err is None and r == 2, f"{r} {err}")
    s.postgres()
    check("the login and profile are gone", not alive(bad) and s.scalar("select count(*) from public.profiles where id = %s", [bad]) == 0)
    check("their events are gone", s.scalar("select count(*) from public.events where id in (%s, %s)", [ev_bad, ev_bad_old]) == 0)
    check("their registrations elsewhere are gone", s.scalar("select count(*) from public.registrations where user_id = %s", [bad]) == 0)
    check("people registered for their upcoming event are told it is cancelled",
          s.scalar("select count(*) from public.notifications where user_id = %s and kind = 'event_cancelled' and event_title = 'Bad upcoming'", [fan]) == 1)
    check("the address is blocked", s.scalar("select count(*) from public.blocked_emails where email = %s", [f"bad-{tag}@haw-hamburg.de"]) == 1)
    s.fails("a blocked address cannot sign up again", "insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at) values "
            "('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', %s, now(), now())",
            [f"BAD-{tag}@haw-hamburg.de"], contains="email_blocked")
    s.user(p_admin)
    r, err = s.call("select public.admin_delete_user(%s)", [victim]); check("a platform admin removes any non-admin user", err is None and r == 0, f"{r} {err}")
    s.postgres()
    check("without blocking, the address stays free", s.scalar("select count(*) from public.blocked_emails where email = %s", [f"victim-{tag}@tum.de"]) == 0)
    s.user(stu_haw)
    s.fails("nobody can read the blocked list directly", "select * from public.blocked_emails", contains="permission denied")

    print("\n[28] Unblocking addresses")
    bad2 = mk_user(f"bad2-{tag}@example.com")
    s.user(p_admin); s.call("select public.admin_delete_user(%s, true)", [bad2])
    bad_mail, bad2_mail = f"bad-{tag}@haw-hamburg.de", f"bad2-{tag}@example.com"
    s.anon()
    s.fails("anonymous cannot list blocked addresses", "select * from public.admin_list_blocked_emails()", contains="permission denied")
    s.fails("anonymous cannot unblock", "select public.admin_unblock_email(%s)", [bad_mail], contains="permission denied")
    s.user(stu_haw)
    _, err = s.call("select * from public.admin_list_blocked_emails()"); check("a student cannot list blocked addresses", err is not None and "not_authorized" in err, str(err))
    _, err = s.call("select public.admin_unblock_email(%s)", [bad_mail]); check("a student cannot unblock", err is not None and "not_authorized" in err, str(err))
    s.user(t_admin)
    mails = [r[0] for r in s.rows("select email from public.admin_list_blocked_emails()")]
    check("a university admin sees their university's blocks", bad_mail in mails, str(mails))
    check("a university admin does not see blocks made by a platform admin", bad2_mail not in mails, str(mails))
    r, _ = s.call("select public.admin_unblock_email(%s)", [bad2_mail]); check("a university admin cannot lift a platform admin's block", r is False, str(r))
    r, _ = s.call("select public.admin_unblock_email(%s)", [bad_mail.upper()]); check("a university admin lifts their university's block (any letter case)", r is True, str(r))
    s.postgres()
    check("the unblocked address can sign up again", s.call("insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at) values "
          "('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', %s, now(), now())", [bad_mail])[1] is None)
    s.user(p_admin)
    mails = [r[0] for r in s.rows("select email from public.admin_list_blocked_emails()")]
    check("a platform admin sees every block", bad2_mail in mails, str(mails))
    r, _ = s.call("select public.admin_unblock_email(%s)", [bad2_mail]); check("a platform admin lifts any block", r is True, str(r))

    print("\n[29] Pre-launch review fixes")
    s.postgres()
    w1 = mk_user(f"w1-{tag}@example.com"); w2 = mk_user(f"w2-{tag}@example.com")
    ev_old = mk_event(commercial, None, "Over with waitlist", capacity=1,
                      start="now() - interval '3 hours'", end="now() - interval '1 hour'")
    s.c.execute("insert into public.registrations (event_id, user_id, status) values (%s, %s, 'registered'), (%s, %s, 'waitlisted')",
                [ev_old, w1, ev_old, w2])
    s.user(w1); _, err = s.call("select public.cancel_registration(%s)", [ev_old])
    s.postgres()
    check("cancelling after an event ended moves nobody up from the waitlist",
          err is None and s.scalar("select status::text from public.registrations where event_id = %s and user_id = %s", [ev_old, w2]) == "waitlisted", str(err))
    check("so nobody gets a 'You got a spot!' for an event that is over",
          s.scalar("select count(*) from public.notifications where user_id = %s and kind = 'waitlist_promoted'", [w2]) == 0)

    ev_c = mk_event(commercial, None, "Cancelled after start", qr=False,
                    start="now() - interval '1 hour'", end="now() + interval '1 hour'")
    s.user(w1); s.call("select public.register_for_event(%s)", [ev_c])
    s.user(commercial); _, err = s.call("update public.events set status = 'cancelled' where id = %s", [ev_c])
    check("the organizer can cancel their event", err is None, str(err))
    _, err = s.call("update public.events set title = 'Renamed after cancel' where id = %s", [ev_c])
    check("a cancelled event can no longer be edited", err is not None and "cancelled_is_final" in err, str(err))
    s.user(w1); _, err = s.call("select public.submit_review(%s, 5, 'nice')", [ev_c])
    check("a cancelled event cannot be reviewed", err is not None and "reviews_not_allowed" in err, str(err))

    print("\n[30] 'How was it?' review invitations")
    r_scan, r_noscan, r_open, r_wait, r_done, r_off = (mk_user(f"rv{i}-{tag}@example.com") for i in range(1, 7))
    ended = dict(start="now() - interval '4 hours'", end="now() - interval '2 hours'")
    ev_qr = mk_event(commercial, None, "Scanned event", capacity=3, **ended)
    ev_open = mk_event(commercial, None, "Open event", qr=False, capacity=1, **ended)
    ev_norev = mk_event(commercial, None, "No reviews", qr=False, reviews=False, **ended)
    ev_soon = mk_event(commercial, None, "Just ended", qr=False, start="now() - interval '2 hours'", end="now() - interval '10 minutes'")
    ev_ancient = mk_event(commercial, None, "Long ago", qr=False, start="now() - interval '10 days'", end="now() - interval '10 days' + interval '2 hours'")
    s.postgres()
    def seat(u, e, status="registered"):
        rid = s.scalar("insert into public.registrations (event_id, user_id, status) values (%s, %s, %s::public.registration_status) returning id", [e, u, status])
        if status == "registered":
            s.c.execute("insert into public.tickets (registration_id, event_id, user_id) values (%s, %s, %s)", [rid, e, u])
    for u in (r_scan, r_noscan, r_done, r_off):
        seat(u, ev_qr)
    seat(r_open, ev_open); seat(r_wait, ev_open, "waitlisted")
    seat(r_open, ev_norev); seat(r_open, ev_soon); seat(r_open, ev_ancient)
    s.c.execute("update public.tickets set checked_in_at = now() - interval '3 hours' where event_id = %s and user_id <> %s", [ev_qr, r_noscan])
    s.c.execute("insert into public.reviews (event_id, ticket_id, user_id, rating, comment, claimed_attendance, is_verified) "
                "select event_id, id, user_id, 5, 'great', true, true from public.tickets where event_id = %s and user_id = %s", [ev_qr, r_done])
    s.c.execute("update public.profiles set notify_reminders = false where id = %s", [r_off])
    s.user(r_scan)
    s.fails("a user cannot run the review invitation job", "select public.queue_review_prompts()", contains="permission denied")
    s.postgres()
    s.scalar("select public.queue_review_prompts()")
    prompted = lambda u, e: s.scalar("select count(*) from public.notifications where user_id = %s and event_id = %s and kind = 'review_prompt'", [u, e])
    check("people scanned in at the door are invited to review", prompted(r_scan, ev_qr) == 1)
    check("people never scanned in at a scanning event are not invited", prompted(r_noscan, ev_qr) == 0)
    check("at events without scanning, registered people are invited", prompted(r_open, ev_open) == 1)
    check("people on the waitlist are not invited", prompted(r_wait, ev_open) == 0)
    check("people who already reviewed are not invited", prompted(r_done, ev_qr) == 0)
    check("people who turned off reminders are not invited", prompted(r_off, ev_qr) == 0)
    check("events without reviews send no invitation", prompted(r_open, ev_norev) == 0)
    check("invitations wait about an hour after the end", prompted(r_open, ev_soon) == 0)
    check("old events send no invitation", prompted(r_open, ev_ancient) == 0)
    s.c.execute("delete from public.notifications where user_id = %s and kind = 'review_prompt'", [r_scan])
    s.scalar("select public.queue_review_prompts()")
    check("each person is invited only once, even after deleting it", prompted(r_scan, ev_qr) == 0)
    check("the invitation job runs every 10 minutes",
          s.scalar("select count(*) from cron.job where jobname = 'unihub-review-prompts' and schedule = '*/10 * * * *'") == 1)

    print("\n[30] Organizers who lost their rights (pen test S2)")
    def upd(q, args=None):
        """Rows changed, or the error text when the statement is refused."""
        try:
            with s.c.transaction():
                return s.c.execute(q, args).rowcount
        except psycopg.Error as e:
            return str(e).splitlines()[0]

    ex_org = mk_user(f"exorg-{tag}@haw-hamburg.de"); promote(ex_org, "organizer")
    ex_fan = mk_user(f"exfan-{tag}@haw-hamburg.de")
    ex_live = mk_event(ex_org, haw, "Ex live", capacity=5)
    ex_draft = mk_event(ex_org, haw, "Ex draft", status="draft")
    ex_draft2 = mk_event(ex_org, haw, "Ex draft 2", status="draft")
    s.user(ex_fan); s.call("select public.register_for_event(%s)", [ex_live])
    ex_code = code_of(ex_fan, ex_live)
    s.user(ex_org)
    check("an organizer in good standing edits their event", upd("update public.events set title = 'Ex live 2' where id = %s", [ex_live]) == 1)
    check("... and sees who registered", len(s.rows("select 1 from public.registrations where event_id = %s", [ex_live])) == 1)
    s.user(p_admin); s.call("select public.admin_set_role(%s,'student',false)", [ex_org])
    s.user(ex_org)
    check("a demoted organizer cannot edit their published event", upd("update public.events set title = 'Hacked' where id = %s", [ex_live]) != 1)
    check("a demoted organizer cannot publish a draft", upd("update public.events set status = 'published' where id = %s", [ex_draft]) != 1)
    check("a demoted organizer cannot cancel-and-rename an event", upd("update public.events set status = 'cancelled', title = 'Rude words' where id = %s", [ex_live]) != 1)
    _, err = s.call("select public.check_in_ticket(%s,%s)", [ex_code, ex_live])
    check("a demoted organizer cannot scan tickets", err is not None and "not_authorized" in err, str(err))
    check("a demoted organizer no longer sees the attendee list", len(s.rows("select 1 from public.registrations where event_id = %s", [ex_live])) == 0)
    check("a demoted organizer no longer sees attendees' tickets", len(s.rows("select 1 from public.tickets where event_id = %s", [ex_live])) == 0)
    check("a demoted organizer still sees their own events", len(s.rows("select 1 from public.events where organizer_id = %s", [ex_org])) == 3)
    check("a demoted organizer can delete their own draft", upd("delete from public.events where id = %s", [ex_draft2]) == 1)
    check("a demoted organizer cannot delete a published event", upd("delete from public.events where id = %s", [ex_live]) != 1)
    s.postgres()
    check("nothing was changed by the demoted organizer",
          s.scalar("select title || '/' || status::text from public.events where id = %s", [ex_live]) == "Ex live 2/published"
          and s.scalar("select status::text from public.events where id = %s", [ex_draft]) == "draft"
          and s.scalar("select checked_in_at is null from public.tickets where code = %s", [ex_code]))
    s.user(t_admin)
    check("the university admin can still manage that event", upd("update public.events set title = 'Ex live 3' where id = %s", [ex_live]) == 1)
    s.user(p_admin)
    check("the platform admin can still manage that event", upd("update public.events set title = 'Ex live 4' where id = %s", [ex_live]) == 1)
    s.user(p_admin); s.call("select public.admin_set_role(%s,'organizer',true)", [ex_org])
    s.user(ex_org)
    check("rights given back: the organizer can edit again", upd("update public.events set title = 'Ex live 5' where id = %s", [ex_live]) == 1)
    _, err = s.call("select public.check_in_ticket(%s,%s)", [ex_code, ex_live])
    check("rights given back: the organizer can scan again", err is None, str(err))
    cap_org0 = mk_user(f"caporg0-{tag}@haw-hamburg.de"); promote(cap_org0, "organizer")
    ex_biz = mk_user(f"exbiz-{tag}@example.com"); promote(ex_biz, "commercial_planner")
    ex_pub = mk_event(ex_biz, None, "Ex public")
    promote(ex_biz, "commercial_planner", verified=False)
    s.user(ex_biz)
    check("a commercial planner whose approval was withdrawn cannot edit", upd("update public.events set title = 'Hacked' where id = %s", [ex_pub]) != 1)
    s.user(cap_org0)
    check("another organizer of the same university still cannot edit it", upd("update public.events set title = 'Hacked' where id = %s", [ex_live]) != 1)
    s.user(ex_org)
    r, err = s.call("insert into public.events (tenant_id, organizer_id, title, location, starts_at, ends_at, status) "
                    "values (%s,%s,'Ex new draft','Somewhere',now()+interval '1 day',now()+interval '2 days','draft') returning id", [haw, ex_org])
    check("saving a draft returns the new event to its creator (B5)", err is None and r is not None, str(err))

    print("\n[31] Seat limit cannot drop below the people registered (pen test B2)")
    cap_org = mk_user(f"caporg-{tag}@haw-hamburg.de"); promote(cap_org, "organizer")
    cap_ev = mk_event(cap_org, haw, "Cap floor", capacity=5)
    cap_a = mk_user(f"capa-{tag}@haw-hamburg.de"); cap_b = mk_user(f"capb-{tag}@haw-hamburg.de")
    for u in (cap_a, cap_b):
        s.user(u); s.call("select public.register_for_event(%s)", [cap_ev])
    s.user(cap_org)
    r = upd("update public.events set capacity = 1 where id = %s", [cap_ev])
    check("limit 5 -> 1 with 2 registered is refused", isinstance(r, str) and "capacity_below_registered" in r, str(r))
    s.user(p_admin)
    r = upd("update public.events set capacity = 1 where id = %s", [cap_ev])
    check("... also for an admin", isinstance(r, str) and "capacity_below_registered" in r, str(r))
    s.user(cap_org)
    check("limit 5 -> 2 (exactly the number registered) is allowed", upd("update public.events set capacity = 2 where id = %s", [cap_ev]) == 1)
    check("raising the limit is allowed", upd("update public.events set capacity = 50 where id = %s", [cap_ev]) == 1)
    check("removing the limit is allowed", upd("update public.events set capacity = null where id = %s", [cap_ev]) == 1)
    check("other edits are not affected", upd("update public.events set title = 'Cap floor 2' where id = %s", [cap_ev]) == 1)

    print("\n[32] Asking first whether the account may be deleted (pen test B1)")
    s.anon()
    s.fails("anonymous cannot ask", "select public.delete_my_account(true)", contains="permission denied")
    s.user(cap_org)
    _, err = s.call("select public.delete_my_account(true)")
    check("asking first: an organizer with events is told no", err is not None and "has_events" in err, str(err))
    s.user(cap_a)
    _, err = s.call("select public.delete_my_account(true)")
    s.postgres()
    check("asking first: a student is told yes and nothing is deleted",
          err is None and s.scalar("select count(*) from auth.users where id = %s", [cap_a]) == 1, str(err))
    s.user(cap_a)
    _, err = s.call("select public.delete_my_account()")
    s.postgres()
    check("the real call still deletes the account", err is None and s.scalar("select count(*) from auth.users where id = %s", [cap_a]) == 0, str(err))

    print("\n[33] Display names (pen test S7, B3)")
    def name_of(uid):
        s.postgres()
        return s.scalar("select display_name from public.profiles where id = %s", [uid])

    def mk_named(email, name):
        s.postgres()
        uid = uuid.uuid4()
        c.execute(
            "insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, raw_user_meta_data, created_at, updated_at) "
            "values ('00000000-0000-0000-0000-000000000000', %s, 'authenticated', 'authenticated', %s, now(), %s::jsonb, now(), now())",
            [uid, email, json.dumps({"display_name": name})])
        return uid

    nm = mk_named(f"nm-{tag}@haw-hamburg.de", "Nora Muster")
    for label, bad in (("'UniHub Admin' with a check mark", "UniHub Admin \u2713"), ("a blank name", "   "),
                       ("'Moderator Max'", "Moderator Max"), ("'ADMINISTRATOR'", "ADMINISTRATOR"),
                       ("a name with an invisible character", "Ma\u200bx"), ("a name with a green tick", "Max \u2705")):
        s.user(nm)
        r = upd("update public.profiles set display_name = %s where id = %s", [bad, nm])
        check(f"a student cannot rename themselves to {label}", isinstance(r, str) and "name_not_allowed" in r and name_of(nm) == "Nora Muster", str(r))
    s.user(nm)
    r = upd("update public.profiles set display_name = %s where id = %s", ["  Anna   Schmidt ", nm])
    check("an ordinary name is saved, tidied up", r == 1 and name_of(nm) == "Anna Schmidt", f"{r} {name_of(nm)!r}")
    s.user(nm)
    r = upd("update public.profiles set display_name = %s where id = %s", ["x" * 81, nm])
    check("a name over 80 letters is cut to 80", r == 1 and len(name_of(nm)) == 80, str(r))
    s.user(p_admin)
    r = upd("update public.profiles set display_name = 'UniHub Admin' where id = %s", [p_admin])
    check("a real admin may call themselves 'UniHub Admin'", r == 1, str(r))
    s.user(p_admin)
    r = upd("update public.profiles set display_name = '  ' where id = %s", [p_admin])
    check("... but not leave the name blank", isinstance(r, str) and "name_not_allowed" in r, str(r))
    s.user(nm)
    check("changing other settings still works", upd("update public.profiles set locale = 'de' where id = %s", [nm]) == 1)
    long_u = mk_named(f"long-{tag}@example.org", "y" * 200)
    check("sign-up with a 200-letter name works; the name is cut to 80", len(name_of(long_u)) == 80)
    fake_u = mk_named(f"faker-{tag}@example.org", "UniHub Admin \u2713")
    check("sign-up as 'UniHub Admin' works but the name is replaced", name_of(fake_u) == f"faker-{tag}", str(name_of(fake_u)))
    fake_u2 = mk_named(f"admin-x{tag}@example.org", "   ")
    check("... and falls back to 'User' when the address is no better", name_of(fake_u2) == "User", str(name_of(fake_u2)))

    print("\n[34] E-mail changes (pen test S5, S6)")
    def tenant_of(uid):
        s.postgres()
        return s.scalar("select tenant_id from public.profiles where id = %s", [uid])

    s.postgres()
    c.execute("insert into public.blocked_emails (email) values (%s)", [f"banned-{tag}@example.org"])
    ch = mk_user(f"changer-{tag}@example.org")
    s.postgres()
    r = upd("update auth.users set email = %s where id = %s", [f"banned-{tag}@example.org", ch])
    check("an account cannot change its e-mail to a blocked address", isinstance(r, str) and "email_blocked" in r, str(r))
    r = upd("update auth.users set email = %s where id = %s", [f"BANNED-{tag}@Example.org", ch])
    check("... also not in capital letters", isinstance(r, str) and "email_blocked" in r, str(r))
    r = upd("update auth.users set email = %s where id = %s", [f"changer2-{tag}@example.org", ch])
    check("changing to an ordinary address works", r == 1, str(r))
    mover = mk_user(f"mover-{tag}@haw-hamburg.de")
    check("a HAW address gives HAW membership", tenant_of(mover) == haw)
    s.postgres(); c.execute("update auth.users set updated_at = now(), email = email where id = %s", [mover])
    check("saving the same address again changes nothing", tenant_of(mover) == haw)
    s.postgres(); c.execute("update auth.users set email = %s where id = %s", [f"mover-{tag}@gmail.com", mover])
    check("changing from HAW to gmail ends the HAW membership", tenant_of(mover) is None, str(tenant_of(mover)))
    s.user(mover)
    check("... so campus events are no longer visible", len(s.rows("select 1 from public.events where tenant_id = %s", [haw])) == 0)
    s.postgres(); c.execute("update auth.users set email = %s where id = %s", [f"mover-{tag}@tum.de", mover])
    check("changing to a TUM address gives TUM membership", tenant_of(mover) == tum)
    s.postgres(); c.execute("update auth.users set email = %s where id = %s", [f"mover-{tag}@stud.haw-hamburg.de", mover])
    check("changing to a HAW sub-domain gives HAW membership", tenant_of(mover) == haw)
    unconf = mk_user(f"unconf-{tag}@gmail.com", confirmed=False)
    s.postgres(); c.execute("update auth.users set email = %s where id = %s", [f"unconf-{tag}@haw-hamburg.de", unconf])
    check("an UNCONFIRMED account gains no membership by changing its address", tenant_of(unconf) is None)
    ex_mail_org = mk_user(f"mailorg-{tag}@haw-hamburg.de"); promote(ex_mail_org, "organizer")
    ev_mail = mk_event(ex_mail_org, haw, "Mail org event")
    s.postgres(); c.execute("update auth.users set email = %s where id = %s", [f"mailorg-{tag}@gmail.com", ex_mail_org])
    s.user(ex_mail_org)
    check("an organizer who leaves the university's address can no longer edit its events",
          upd("update public.events set title = 'Hacked' where id = %s", [ev_mail]) != 1)

    print("\n[35] Removing a single review, and the feedback list (pen test S8, B4)")
    rv_org = mk_user(f"rvorg-{tag}@tum.de"); promote(rv_org, "organizer")
    rv_org2 = mk_user(f"rvorg2-{tag}@tum.de"); promote(rv_org2, "organizer")
    rv_t_admin = mk_user(f"rvadm-{tag}@tum.de"); promote(rv_t_admin, "tenant_admin")
    rv_ev = mk_event(rv_org, tum, "Review removal", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=False)
    rv_ev2 = mk_event(rv_org2, tum, "Other reviews", start="now() - interval '1 hour'", end="now() + interval '2 hours'", qr=False)
    rv_users = [mk_user(f"rv{i}-{tag}@tum.de") for i in range(3)]
    for u in rv_users:
        for ev in (rv_ev, rv_ev2):
            s.user(u); s.call("select public.register_for_event(%s)", [ev])
            s.user(u); s.call("select public.submit_review(%s,1,'rude words',true)", [ev])
    s.postgres()
    rv_ids = [r[0] for r in s.rows("select id from public.reviews where event_id = %s order by created_at, id", [rv_ev])]
    check("three reviews exist to work with", len(rv_ids) == 3, str(len(rv_ids)))

    def review_exists(rid):
        s.postgres()
        return s.scalar("select count(*) from public.reviews where id = %s", [rid]) == 1

    s.anon()
    s.fails("anonymous cannot remove a review", "select public.admin_delete_review(%s)", [rv_ids[0]], contains="permission denied")
    s.fails("anonymous cannot read the feedback list", "select * from public.my_event_feedback()", contains="permission denied")
    for who, uid in (("a student", rv_users[0]), ("the event's organizer", rv_org), ("a university admin of ANOTHER university", t_admin)):
        s.user(uid)
        _, err = s.call("select public.admin_delete_review(%s)", [rv_ids[0]])
        check(f"{who} cannot remove a review", err is not None and "not_authorized" in err and review_exists(rv_ids[0]), str(err))
    s.user(rv_users[0])
    check("the author cannot delete the row directly either", upd("delete from public.reviews where id = %s", [rv_ids[0]]) != 1 and review_exists(rv_ids[0]))
    s.user(rv_t_admin)
    _, err = s.call("select public.admin_delete_review(%s)", [rv_ids[0]])
    check("the university's own admin removes a review", err is None and not review_exists(rv_ids[0]), str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_delete_review(%s)", [rv_ids[1]])
    check("the platform admin removes a review", err is None and not review_exists(rv_ids[1]), str(err))
    check("the other reviews are untouched", review_exists(rv_ids[2]))
    s.user(p_admin)
    _, err = s.call("select public.admin_delete_review(%s)", [rv_ids[1]])
    check("removing a review that is gone says not_found", err is not None and "not_found" in err, str(err))

    s.user(rv_org)
    fb = s.rows("select event_id, event_title, comment from public.my_event_feedback()")
    check("an organizer's feedback list holds only THEIR events", len(fb) == 1 and all(r[0] == rv_ev for r in fb), str(fb))
    check("... with the event title", bool(fb) and fb[0][1] == "Review removal")
    s.user(rv_org2)
    fb = s.rows("select event_id from public.my_event_feedback()")
    check("another organizer gets only their own", len(fb) == 3 and all(r[0] == rv_ev2 for r in fb), str(fb))
    check("the list size can be limited", len(s.rows("select 1 from public.my_event_feedback(2)")) == 2)
    s.user(rv_users[0])
    check("a student gets an empty feedback list", len(s.rows("select 1 from public.my_event_feedback()")) == 0)
    s.postgres()
    cols = {r[0] for r in s.rows("select unnest(proargnames) from pg_proc where proname = 'my_event_feedback'")}
    check("the feedback list does not reveal who wrote a review", "user_id" not in cols and "event_title" in cols, str(cols))

    print("\n[36] University roles need a university e-mail")
    gm = mk_user(f"gm-{tag}@gmail.com")
    uni_u = mk_user(f"uniu-{tag}@haw-hamburg.de")
    for role in ("organizer", "tenant_admin"):
        s.user(p_admin)
        _, err = s.call(f"select public.admin_set_role(%s,'{role}',true)", [gm])
        check(f"a Gmail account cannot be made {role}", err is not None and "needs_university_email" in err and role_of(gm) == "student", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'commercial_planner',true)", [gm])
    check("a Gmail account can be made a commercial planner", err is None and role_of(gm) == "commercial_planner", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [gm])
    check("... and back to student", err is None and role_of(gm) == "student", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'organizer',true)", [uni_u])
    check("a university account can be made organizer", err is None and role_of(uni_u) == "organizer", str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'tenant_admin',true)", [uni_u])
    check("a university account can be made university admin", err is None and role_of(uni_u) == "tenant_admin", str(err))
    left_uni = mk_user(f"leftuni-{tag}@haw-hamburg.de")
    s.postgres()
    rq = s.scalar("insert into public.organizer_requests (user_id, email, requested_role, organization_name, message, applicant_position, phone) "
                  "values (%s, %s, 'organizer', 'Club', '', 'Chair', '+49 40 123456') returning id", [left_uni, f"leftuni-{tag}@haw-hamburg.de"])
    c.execute("update auth.users set email = %s where id = %s", [f"leftuni-{tag}@gmail.com", left_uni])
    s.user(p_admin)
    _, err = s.call("select public.review_organizer_request(%s, true)", [rq])
    check("an organizer request cannot be approved after the applicant left the university address",
          err is not None and "needs_university_email" in err and role_of(left_uni) == "student", str(err))
    s.user(p_admin)
    _, err = s.call("select public.review_organizer_request(%s, false, 'no longer at HAW')", [rq])
    check("... but it can be rejected", err is None, str(err))

    print("\n[37] Case files keep the reports as evidence")
    cf_org = mk_user(f"cforg-{tag}@tum.de"); promote(cf_org, "organizer")
    cf_ev = mk_event(cf_org, tum, "Case event")
    cf_ev2 = mk_event(cf_org, tum, "Case event two")
    cf_rep = [mk_user(f"cfrep{i}-{tag}@tum.de") for i in range(3)]
    for u, reason, text in ((cf_rep[0], "spam", "Only adverts"), (cf_rep[1], "scam", "Asks for money")):
        s.user(u); s.call("select public.report_event(%s,%s,%s)", [cf_ev, reason, text])
    s.user(cf_rep[2]); s.call("select public.report_event(%s,'misleading','Wrong place')", [cf_ev2])
    s.postgres()
    cf_open = s.scalar("select id from public.event_reports where event_id = %s order by created_at limit 1", [cf_ev])
    cases_before = s.scalar("select count(*) from public.moderation_cases")
    s.user(cf_rep[0])
    _, err = s.call("select public.resolve_report(%s, false)", [cf_open])
    s.postgres()
    check("a refused action writes no case file", err is not None and s.scalar("select count(*) from public.moderation_cases") == cases_before)
    s.user(p_admin)
    _, err = s.call("select public.resolve_report(%s, true, 'Advertising only')", [cf_open])
    s.postgres()
    case = s.rows("select action, subject_user_id, subject_email, event_title, note, report_count, evidence, decided_by, tenant_id "
                  "from public.moderation_cases where event_title = 'Case event'")
    check("removing a reported event writes one case file", err is None and len(case) == 1, f"{err} {len(case)}")
    if case:
        a, subj, mail, title, note, cnt, ev, by, ten = case[0]
        check("the case names the organizer, the event, the admin and the note",
              a == "event_removed" and subj == cf_org and mail == f"cforg-{tag}@tum.de" and note == "Advertising only" and by == p_admin and ten == tum,
              str(case[0][:5]))
        check("it holds both reports about that event as evidence", cnt == 2 and {x["reason"] for x in ev} == {"spam", "scam"}
              and {x["details"] for x in ev} == {"Only adverts", "Asks for money"}, str(ev))
        check("the evidence does not say WHO reported", all(set(x) == {"event_title", "reason", "details", "reported_at", "outcome"} for x in ev)
              and not any(str(u) in json.dumps(ev) for u in cf_rep), str(ev))
    s.user(p_admin)
    _, err = s.call("select public.resolve_report((select id from public.event_reports where event_id = %s limit 1), false)", [cf_ev2])
    s.postgres()
    check("dismissing a report writes no case file", err is None and s.scalar("select count(*) from public.moderation_cases where subject_user_id = %s", [cf_org]) == 1, str(err))

    s.user(p_admin)
    r, err = s.call("select public.admin_delete_user(%s, true)", [cf_org])
    s.postgres()
    case = s.rows("select subject_email, email_blocked, report_count, evidence, subject_name from public.moderation_cases "
                  "where action = 'user_removed' and subject_user_id = %s", [cf_org])
    check("removing a user writes a case file", err is None and len(case) == 1, f"{err} {len(case)}")
    if case:
        mail, blocked, cnt, ev, _ = case[0]
        check("it keeps the address, that it was blocked, and ALL reports about their events",
              mail == f"cforg-{tag}@tum.de" and blocked is True and cnt == 3 and {x["event_title"] for x in ev} == {"Case event", "Case event two"}, str(case[0][:3]))
    check("the reports themselves are gone with the events, the case files are not",
          s.scalar("select count(*) from public.event_reports where event_id in (%s,%s)", [cf_ev, cf_ev2]) == 0
          and s.scalar("select count(*) from public.moderation_cases where subject_user_id = %s", [cf_org]) == 2)
    clean_user = mk_user(f"clean-{tag}@tum.de")
    s.user(p_admin); s.call("select public.admin_delete_user(%s)", [clean_user])
    s.postgres()
    check("removing a user nobody reported records that too, with no evidence and no block",
          s.rows("select report_count, email_blocked from public.moderation_cases where subject_user_id = %s", [clean_user]) == [(0, False)])

    s.anon()
    s.fails("anonymous cannot read case files", "select * from public.admin_list_cases()", contains="permission denied")
    s.fails("anonymous cannot read the table", "select * from public.moderation_cases", contains="permission denied")
    s.user(cf_rep[0])
    _, err = s.call("select count(*) from public.admin_list_cases()")
    check("a student cannot read case files", err is not None and "not_authorized" in err, str(err))
    s.fails("a signed-in user cannot read the table directly", "select * from public.moderation_cases", contains="permission denied")
    s.fails("... nor write to it", "insert into public.moderation_cases (action) values ('user_removed')", contains="permission denied")
    s.user(rv_t_admin)
    mine = s.rows("select subject_email from public.admin_list_cases()")
    check("a university admin reads the case files of their own university", any(m[0] == f"cforg-{tag}@tum.de" for m in mine), str(mine[:3]))
    s.user(t_admin)
    other = s.rows("select subject_email from public.admin_list_cases()")
    check("... but not those of another university", all(m[0] != f"cforg-{tag}@tum.de" for m in other), str(other[:3]))
    s.user(p_admin)
    allc = s.rows("select subject_email, evidence from public.admin_list_cases()")
    check("the platform admin reads all case files", sum(1 for m in allc if m[0] == f"cforg-{tag}@tum.de") == 2)
    s.postgres()
    check("old case files are deleted automatically (after 12 months)",
          s.scalar("select count(*) from cron.job where jobname = 'unihub-cases-cleanup' and command ilike '%%12 months%%'") == 1)

    print("\n[38] Suspending an account (the step before removing it)")
    su_org = mk_user(f"suorg-{tag}@tum.de"); promote(su_org, "organizer")
    su_com = mk_user(f"sucom-{tag}@gmail.com"); promote(su_com, "commercial_planner")
    su_ev = mk_event(su_org, tum, "Suspended campus event")
    su_pub = mk_event(su_com, None, "Suspended public event")
    su_holder = mk_user(f"suhold-{tag}@tum.de")
    su_new = mk_user(f"sunew-{tag}@tum.de")
    su_stu = mk_user(f"sustu-{tag}@tum.de")
    su_tadmin = mk_user(f"suadm-{tag}@tum.de"); promote(su_tadmin, "tenant_admin")
    s.user(su_holder); s.call("select public.register_for_event(%s)", [su_ev])
    s.user(su_stu); s.call("select public.register_for_event(%s)", [su_ev])
    s.user(su_new); s.call("select public.report_event(%s,'spam','Looks fake')", [su_ev])

    def sees(uid, ev):
        s.anon() if uid is None else s.user(uid)
        return s.scalar("select count(*) from public.events where id = %s", [ev]) == 1

    def suspended(uid):
        s.postgres()
        return s.scalar("select suspended_at is not null from public.profiles where id = %s", [uid])

    check("before: the events are in the feed", sees(su_new, su_ev) and sees(None, su_pub))
    s.anon()
    s.fails("anonymous cannot suspend anyone", "select public.admin_set_suspended(%s, true, 'x')", [su_org], contains="permission denied")
    for who, label in ((su_stu, "a student"), (su_org, "an organizer"), (t_admin, "another university's admin")):
        s.user(who)
        _, err = s.call("select public.admin_set_suspended(%s, true, 'because')", [su_stu if who == su_org else su_org])
        check(f"{label} cannot suspend anyone", err is not None and "not_authorized" in err, str(err))
    s.user(su_stu)
    s.fails("nobody can set the suspension on their own profile row", "update public.profiles set suspended_at = now() where id = %s", [su_stu], contains="permission denied")
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, '  ')", [su_org])
    check("a suspension needs a written reason", err is not None and "note_required" in err and not suspended(su_org), str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'x')", [p_admin])
    check("an admin cannot suspend themselves", err is not None and "cannot_suspend_self" in err, str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'x')", [su_tadmin])
    check("an admin must be demoted before being suspended", err is not None and "demote_first" in err, str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, false)", [su_org])
    check("reinstating someone who is not suspended is refused", err is not None and "no_change" in err, str(err))

    s.user(su_tadmin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'Three reports, checking')", [su_org])
    check("a university admin can suspend an organizer of their university", err is None and suspended(su_org), str(err))
    s.postgres()
    check("the suspended person gets a notification",
          s.scalar("select count(*) from public.notifications where user_id = %s and kind = 'account_suspended'", [su_org]) == 1)
    s.user(su_tadmin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'x')", [su_com])
    check("... but not an account outside their university", err is not None and "not_authorized" in err and not suspended(su_com), str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'again')", [su_org])
    check("suspending twice is refused", err is not None and "no_change" in err, str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'Reported as a scam')", [su_com])
    check("the platform admin can suspend a commercial planner", err is None and suspended(su_com), str(err))

    check("the suspended organizer's campus event leaves the feed", not sees(su_new, su_ev))
    check("their public event leaves the feed for signed-in users", not sees(su_new, su_pub))
    check("... and for visitors", not sees(None, su_pub))
    check("people who already hold a ticket still see the event", sees(su_holder, su_ev))
    check("the organizer still sees their own event", sees(su_org, su_ev))
    check("admins still see it", sees(p_admin, su_ev) and sees(su_tadmin, su_ev))
    s.user(su_new)
    _, err = s.call("select public.register_for_event(%s)", [su_ev])
    check("nobody new can sign up for a suspended organizer's event", err is not None and "event_not_available" in err, str(err))
    s.user(su_holder)
    _, err = s.call("select public.cancel_registration(%s)", [su_ev])
    check("a ticket holder can still cancel", err is None, str(err))
    s.user(su_holder)
    _, err = s.call("select public.register_for_event(%s)", [su_ev])
    check("... but not sign up again while the organizer is suspended", err is not None and "event_not_available" in err, str(err))
    s.user(su_org)
    s.affects_nothing("the suspended organizer cannot edit their event", "update public.events set title = 'Hacked' where id = %s", [su_ev])
    s.fails("... nor publish a new one",
            "insert into public.events (tenant_id, organizer_id, title, location, starts_at, ends_at, categories, status) "
            "values (%s, %s, 'New', 'X', now() + interval '2 days', now() + interval '2 days 1 hour', array['Tech'], 'published')", [tum, su_org])
    s.user(su_org)
    check("... and no longer counts as a publisher", s.scalar("select public.is_verified_publisher()") is False
          and s.scalar("select public.can_publish_for(%s)", [tum]) is False and s.scalar("select public.can_manage_event(%s)", [su_ev]) is False)
    s.user(su_org)
    check("the suspended account can read that it is suspended", s.scalar("select suspended_at is not null from public.profiles where id = %s", [su_org]) is True)
    s.user(su_tadmin)
    listed = s.rows("select id, suspended_at from public.admin_list_users(%s)", [f"suorg-{tag}"])
    check("the admin user list shows the suspension", len(listed) == 1 and listed[0][1] is not None, str(listed))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'organizer',true)", [su_org])
    s.user(p_admin)
    _, err2 = s.call("select public.admin_set_role(%s,'student',false)", [su_com])
    check("a suspended account cannot be given a publishing role, only be made a student",
          err is not None and "account_suspended" in err and err2 is None and role_of(su_com) == "student", f"{err} / {err2}")

    s.user(p_admin)
    _, err = s.call("select public.admin_set_suspended(%s, true, 'Abusive reviews')", [su_stu])
    other_ev = mk_event(org_tum, tum, "Another event")
    started = mk_event(org_tum, tum, "Started event", start="now() - interval '1 hour'", end="now() + interval '1 hour'", qr=False)
    s.user(su_stu)
    _, e1 = s.call("select public.register_for_event(%s)", [other_ev])
    s.user(su_stu)
    _, e2 = s.call("select public.report_event(%s,'spam','x')", [other_ev])
    check("a suspended student cannot sign up for events", err is None and e1 is not None and "account_suspended" in e1, f"{err} / {e1}")
    check("... nor report events", e2 is not None and "account_suspended" in e2, str(e2))
    s.postgres()
    reg = s.scalar("select id from public.registrations where user_id = %s and event_id = %s", [su_stu, su_ev])
    c.execute("update public.events set starts_at = now() - interval '1 hour', requires_qr = false where id = %s", [su_ev])
    s.user(su_stu)
    _, e3 = s.call("select public.submit_review(%s, 1, 'Terrible', true)", [su_ev])
    check("... nor write reviews", reg is not None and e3 is not None and "account_suspended" in e3, str(e3))
    s.postgres()
    check("their existing ticket stays valid", s.scalar("select count(*) from public.tickets where user_id = %s and event_id = %s and voided_at is null", [su_stu, su_ev]) == 1)
    s.user(su_stu)
    _, err = s.call("select public.cancel_registration(%s)", [su_ev])
    check("... and they can still cancel it", err is None, str(err))

    s.postgres()
    case = s.rows("select action, note, report_count, subject_email, decided_by, tenant_id from public.moderation_cases "
                  "where subject_user_id = %s order by created_at", [su_org])
    check("the suspension is in the case files with the reason and the reports",
          len(case) == 1 and case[0][0] == "user_suspended" and case[0][1] == "Three reports, checking" and case[0][2] == 1
          and case[0][3] == f"suorg-{tag}@tum.de" and case[0][4] == su_tadmin and case[0][5] == tum, str(case))
    s.user(su_stu)
    _, err = s.call("select public.admin_set_suspended(%s, false)", [su_org])
    check("a student cannot reinstate anyone", err is not None and "not_authorized" in err and suspended(su_org), str(err))
    s.user(su_tadmin)
    _, err = s.call("select public.admin_set_suspended(%s, false, 'Reports were unfounded')", [su_org])
    check("the admin can reinstate the organizer", err is None and not suspended(su_org), str(err))
    s.postgres()
    check("... who gets a notification about that too",
          s.scalar("select count(*) from public.notifications where user_id = %s and kind = 'account_reinstated'", [su_org]) == 1)
    s.postgres()
    case = s.rows("select action, note from public.moderation_cases where subject_user_id = %s order by created_at, action desc", [su_org])
    check("the reinstatement is in the case files too", sorted(x[0] for x in case) == ["user_reinstated", "user_suspended"]
          and ("user_reinstated", "Reports were unfounded") in case, str(case))
    check("after reinstating, the event is back in the feed", sees(su_new, su_ev))
    s.user(su_org)
    check("... and the organizer can manage it again", s.scalar("select public.can_manage_event(%s)", [su_ev]) is True)
    s.postgres()
    c.execute("update public.events set starts_at = now() + interval '1 day' where id = %s", [su_ev])
    s.user(su_new)
    _, err = s.call("select public.register_for_event(%s)", [su_ev])
    check("... and people can sign up again", err is None, str(err))
    s.user(p_admin)
    r, err = s.call("select public.admin_delete_user(%s, true)", [su_com])
    s.postgres()
    acts = [x[0] for x in s.rows("select action from public.moderation_cases where subject_user_id = %s", [su_com])]
    check("a suspended account can then be removed; both steps stay on record",
          err is None and sorted(acts) == ["user_removed", "user_suspended"], f"{err} {acts}")

    print("\n[39] Yearly check of university addresses")
    import time as _time

    def user_amr(uid, method, age_seconds):
        """Signed in as uid, in a session that was started with `method` so many seconds ago."""
        s.postgres()
        c.execute("select set_config('request.jwt.claims', %s, true)",
                  [json.dumps({"sub": str(uid), "role": "authenticated",
                               "amr": [{"method": method, "timestamp": int(_time.time()) - age_seconds}]})])
        c.execute("select set_config('request.jwt.claim.sub', %s, true)", [str(uid)])
        c.execute("set local role authenticated")

    def prof(uid, cols):
        s.postgres()
        return s.rows(f"select {cols} from public.profiles where id = %s", [uid])[0]

    def age(uid, checked, notified=None):
        s.postgres()
        c.execute(f"update public.profiles set email_checked_at = now() - interval '{checked}', "
                  + ("email_check_notified_at = null" if notified is None else f"email_check_notified_at = now() - interval '{notified}'")
                  + " where id = %s", [uid])

    def run_checks():
        s.postgres()
        c.execute("select public.process_email_checks()")

    def notes(uid, kind):
        s.postgres()
        return s.scalar("select count(*) from public.notifications where user_id = %s and kind = %s", [uid, kind])

    yc_stu = mk_user(f"ycstu-{tag}@tum.de")
    yc_org = mk_user(f"ycorg-{tag}@tum.de"); promote(yc_org, "organizer")
    yc_asta = mk_user(f"ycasta-{tag}@tum.de"); promote(yc_asta, "organizer")
    yc_new = mk_user(f"ycnew-{tag}@tum.de")
    yc_gmail = mk_user(f"ycgm-{tag}@gmail.com")
    yc_tadm = mk_user(f"ycadm-{tag}@tum.de"); promote(yc_tadm, "tenant_admin")
    yc_root = mk_user(f"ycroot-{tag}@tum.de"); promote(yc_root, "platform_admin")
    check("a new account starts with a freshly checked address", prof(yc_new, "email_checked_at > now() - interval '5 minutes', email_check_exempt") == (True, False))

    s.anon()
    s.fails("anonymous cannot confirm an address", "select public.confirm_university_email()", contains="permission denied")
    s.user(yc_stu)
    s.fails("nobody can move their own check date", "update public.profiles set email_checked_at = now() where id = %s", [yc_stu], contains="permission denied")
    s.fails("... or exempt themselves", "update public.profiles set email_check_exempt = true where id = %s", [yc_stu], contains="permission denied")
    s.fails("users cannot run the yearly job", "select public.process_email_checks()", contains="permission denied")

    for u in (yc_stu, yc_org, yc_asta, yc_gmail, yc_tadm, yc_root):
        age(u, "13 months")
    s.user(p_admin)
    _, err = s.call("select public.admin_set_email_check(%s, true)", [yc_asta])
    check("the platform admin can exempt an organization address", err is None and prof(yc_asta, "email_check_exempt")[0] is True, str(err))
    run_checks()
    check("after a year, a student is asked to confirm", notes(yc_stu, "email_check_due") == 1 and prof(yc_stu, "email_check_notified_at is not null, tenant_id")[0:2] == (True, tum))
    check("... and so are an organizer and a university admin", notes(yc_org, "email_check_due") == 1 and notes(yc_tadm, "email_check_due") == 1)
    check("an exempt organization address is not asked", notes(yc_asta, "email_check_due") == 0)
    check("an account without a university is not asked", notes(yc_gmail, "email_check_due") == 0)
    check("a platform admin is never asked", notes(yc_root, "email_check_due") == 0)
    check("a recent account is not asked", notes(yc_new, "email_check_due") == 0)
    run_checks()
    check("nobody is asked twice, and nobody loses anything inside the 30 days",
          notes(yc_stu, "email_check_due") == 1 and prof(yc_org, "role::text, tenant_id") == ("organizer", tum))

    s.user(yc_stu)
    _, err = s.call("select public.confirm_university_email()")
    check("confirming needs a session started with an e-mailed code", err is not None and "fresh_code_required" in err, str(err))
    user_amr(yc_stu, "password", 10)
    _, err = s.call("select public.confirm_university_email()")
    check("a password sign-in is not proof", err is not None and "fresh_code_required" in err, str(err))
    user_amr(yc_stu, "otp", 3600)
    _, err = s.call("select public.confirm_university_email()")
    check("an old code sign-in is not proof either", err is not None and "fresh_code_required" in err, str(err))
    user_amr(yc_stu, "otp", 30)
    _, err = s.call("select public.confirm_university_email()")
    check("a fresh code sign-in confirms the address",
          err is None and prof(yc_stu, "email_checked_at > now() - interval '5 minutes', email_check_notified_at is null") == (True, True), str(err))

    for u in (yc_stu, yc_org, yc_tadm, yc_asta):
        s.postgres()
        c.execute("update public.profiles set email_check_notified_at = now() - interval '31 days' where id = %s and email_check_notified_at is not null", [u])
    ycl_stu = mk_user(f"yclapse-{tag}@tum.de")
    age(ycl_stu, "14 months", "31 days")
    ycl_ev = mk_event(yc_org, tum, "Event of a lapsing organizer")
    run_checks()
    check("the student who confirmed keeps the university", prof(yc_stu, "tenant_id, email_check_lapsed_at")[0:2] == (tum, None))
    check("30 days without confirming: a student loses the university, nothing else",
          prof(ycl_stu, "tenant_id, role::text, email_check_lapsed_at is not null") == (None, "student", True) and notes(ycl_stu, "email_check_lapsed") == 1)
    check("... an organizer becomes a plain student without a university",
          prof(yc_org, "tenant_id, role::text, organizer_verified") == (None, "student", False) and notes(yc_org, "email_check_lapsed") == 1)
    check("... and so does a university admin", prof(yc_tadm, "tenant_id, role::text") == (None, "student"))
    check("the exempt organization address is untouched", prof(yc_asta, "tenant_id, role::text, organizer_verified") == (tum, "organizer", True))
    s.user(yc_org)
    check("the lapsed organizer can no longer manage or publish", s.scalar("select public.can_manage_event(%s)", [ycl_ev]) is False
          and s.scalar("select public.can_publish_for(%s)", [tum]) is False)
    s.user(ycl_stu)
    check("the lapsed student no longer sees campus events", s.scalar("select count(*) from public.events where id = %s", [ycl_ev]) == 0)
    s.postgres()
    check("no account or event was deleted", s.scalar("select count(*) from public.events where id = %s", [ycl_ev]) == 1
          and s.scalar("select count(*) from auth.users where id in (%s,%s,%s)", [ycl_stu, yc_org, yc_tadm]) == 3)
    user_amr(ycl_stu, "otp", 20)
    _, err = s.call("select public.confirm_university_email()")
    check("confirming later brings the university back", err is None and prof(ycl_stu, "tenant_id, email_check_lapsed_at") == (tum, None), str(err))
    user_amr(yc_gmail, "otp", 20)
    _, err = s.call("select public.confirm_university_email()")
    check("confirming a private address never creates a university", err is None and prof(yc_gmail, "tenant_id")[0] is None, str(err))

    age(yc_new, "13 months", "31 days")
    s.postgres()
    c.execute("update auth.users set email = %s where id = %s", [f"ycnew2-{tag}@tum.de", yc_new])
    run_checks()
    check("changing to a new (confirmed) address starts the year again",
          prof(yc_new, "email_checked_at > now() - interval '5 minutes', tenant_id") == (True, tum) and notes(yc_new, "email_check_lapsed") == 0)

    yc_org2 = mk_user(f"ycorg2-{tag}@tum.de"); promote(yc_org2, "organizer")
    yc_org_haw = mk_user(f"ycorgh-{tag}@haw-hamburg.de"); promote(yc_org_haw, "organizer")
    yc_tadm2 = mk_user(f"ycadm2-{tag}@tum.de"); promote(yc_tadm2, "tenant_admin")
    for who, label in ((yc_stu, "a student"), (yc_org2, "an organizer (for themselves)"), (t_admin, "another university's admin")):
        s.user(who)
        _, err = s.call("select public.admin_set_email_check(%s, true)", [yc_org2])
        check(f"{label} cannot switch the yearly check off", err is not None and "not_authorized" in err, str(err))
    s.user(yc_tadm2)
    _, err = s.call("select public.admin_set_email_check(%s, true)", [yc_tadm2])
    check("a university admin cannot exempt themselves", err is not None and "not_authorized" in err, str(err))
    s.user(yc_tadm2)
    _, err = s.call("select public.admin_set_email_check(%s, true)", [yc_org2])
    check("a university admin can exempt an organizer of their university", err is None and prof(yc_org2, "email_check_exempt")[0] is True, str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_email_check(%s, true)", [yc_stu])
    check("a plain student can never be exempt", err is not None and "only_university_organizers" in err, str(err))
    s.user(yc_tadm2)
    listed = s.rows("select email_check_exempt, email_checked_at from public.admin_list_users(%s)", [f"ycorg2-{tag}"])
    check("the admin user list shows the exemption", listed == [(True, listed[0][1])] and listed[0][1] is not None, str(listed))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_role(%s,'student',false)", [yc_org2])
    check("an exemption ends when the account is made a student again", err is None and prof(yc_org2, "email_check_exempt")[0] is False, str(err))
    s.user(p_admin)
    _, err = s.call("select public.admin_set_email_check(%s, false)", [yc_asta])
    check("the admin can switch the check back on", err is None and prof(yc_asta, "email_check_exempt")[0] is False, str(err))

    def mk_request(uid, mail, role="organizer"):
        s.postgres()
        return s.scalar("insert into public.organizer_requests (user_id, email, requested_role, organization_name, message, applicant_position, phone) "
                        "values (%s, %s, %s::public.user_role, 'Club', '', 'Chair', '+49 40 123456') returning id", [uid, mail, role])

    ra, rb, rc = (mk_user(f"ycreq{i}-{tag}@{d}") for i, d in ((1, "tum.de"), (2, "tum.de"), (3, "gmail.com")))
    qa, qb, qc = mk_request(ra, "a"), mk_request(rb, "b"), mk_request(rc, "c", "commercial_planner")
    s.user(p_admin)
    _, e1 = s.call("select public.review_organizer_request(%s, true, null, true)", [qa])
    s.user(p_admin)
    _, e2 = s.call("select public.review_organizer_request(%s, true)", [qb])
    s.user(p_admin)
    _, e3 = s.call("select public.review_organizer_request(%s, true, null, true)", [qc])
    check("approving as a permanent organization address switches the yearly check off",
          e1 is None and prof(ra, "role::text, email_check_exempt") == ("organizer", True), str(e1))
    check("approving normally keeps the yearly check", e2 is None and prof(rb, "role::text, email_check_exempt") == ("organizer", False), str(e2))
    check("a commercial planner is never marked exempt", e3 is None and prof(rc, "role::text, email_check_exempt") == ("commercial_planner", False), str(e3))
    s.postgres()
    check("the yearly check runs every day", s.scalar("select count(*) from cron.job where jobname = 'unihub-email-checks'") == 1)

    print("\n[13] Privileges audit (what is exposed at all)")
    s.postgres()
    allowed_exec = {
        "anon": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count",
                 "categories_ok", "event_seat_counts", "is_suspended"},
        "authenticated": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count",
                          "register_for_event", "cancel_registration", "check_in_ticket", "submit_review", "admin_set_role",
                          "is_verified_publisher", "user_tenant", "request_organizer_access",
                          "review_organizer_request", "admin_list_users", "delete_my_account",
                          "may_have_avatar", "can_have_avatar", "categories_ok", "my_organizer_doc_count",
                          "can_moderate_event", "report_event", "resolve_report",
                          "register_push_token", "unregister_push_token", "confirm_attendance", "event_insights",
                          "event_seat_counts", "admin_delete_user", "admin_list_blocked_emails", "admin_unblock_email",
                          "admin_delete_review", "my_event_feedback", "admin_list_cases", "admin_set_suspended", "is_suspended", "confirm_university_email", "admin_set_email_check"},
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
        "moderation_cases": (set(), set()),
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

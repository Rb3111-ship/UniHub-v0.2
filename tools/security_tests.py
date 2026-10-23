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
    _, err = s.call("select public.request_organizer_access('organizer', 'HAW Film Club', 'We screen films')"); check("student with a university can request organizer access", err is None, str(err))
    _, err = s.call("select public.request_organizer_access('organizer', 'Again', '')"); check("a second pending request is refused", err is not None and "request_pending" in err, str(err))
    for bad in ("platform_admin", "tenant_admin", "student"):
        _, err = s.call("select public.request_organizer_access(%s::public.user_role, 'X Org', '')", [bad]); check(f"cannot request the {bad} role", err is not None, "accepted")
    s.user(rq_pub)
    _, err = s.call("select public.request_organizer_access('organizer', 'Fake Uni Club', '')"); check("no university -> cannot request university organizer", err is not None and "no_university" in err, str(err))
    _, err = s.call("select public.request_organizer_access('commercial_planner', 'Acme Events', 'We run concerts')"); check("anyone can request commercial planner access", err is None, str(err))
    _, err = s.call("select public.request_organizer_access('commercial_planner', %s, '')", ["x"]); check("request needs a real organization name", err is not None)
    s.user(rq_tum)
    s.call("select public.request_organizer_access('organizer', 'TUM Robotics', '')")
    s.user(org_tum)
    _, err = s.call("select public.request_organizer_access('organizer', 'Already one', '')"); check("an existing organizer cannot request again", err is not None and "already_organizer" in err, str(err))
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
    _, err = s.call("select public.request_organizer_access('commercial_planner', 'Acme Events', 'Second try')"); check("after a rejection the user may apply again", err is None, str(err))
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

    print("\n[13] Privileges audit (what is exposed at all)")
    s.postgres()
    allowed_exec = {
        "anon": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count"},
        "authenticated": {"auth_role", "auth_tenant", "is_platform_admin", "can_publish_for", "can_manage_event", "event_registered_count",
                          "register_for_event", "cancel_registration", "check_in_ticket", "submit_review", "admin_set_role",
                          "is_verified_publisher", "user_tenant", "request_organizer_access",
                          "review_organizer_request", "admin_list_users", "delete_my_account",
                          "may_have_avatar", "can_have_avatar"},
    }
    funcs = s.rows("select p.proname, has_function_privilege('anon', p.oid, 'execute'), has_function_privilege('authenticated', p.oid, 'execute'), "
                   "p.prosecdef, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'")
    for name, a, au, secdef, cfg in funcs:
        check(f"function {name}: anon access is exactly as intended", a == (name in allowed_exec["anon"]))
        check(f"function {name}: signed-in access is exactly as intended", au == (name in allowed_exec["authenticated"]))
        if secdef:
            check(f"function {name}: SECURITY DEFINER has a fixed search_path", bool(cfg) and any("search_path" in x for x in cfg))
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

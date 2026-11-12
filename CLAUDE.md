# UniHub: notes for Claude

UniHub is a Flutter app for university events: students find events, register, get QR tickets and review events; organizers publish events and scan tickets at the door; admins approve organizers and moderate. It runs on Android (APK) and the web. The backend is Supabase.

## Working with the owner

- The owner is new to programming and works on Windows 11. Explain things in plain words, avoid jargon, and give PowerShell commands they can copy.
- They test on their Android phone using APKs in `D:\UniHub_APK` (named `UniHub-v<version>.apk`). They put screenshots there too.
- Push to GitHub (`origin` = github.com/Rb3111-ship/UniHub-v0.2, branch `main`) only when they ask. They have generally said "you can push it" for finished, tested work. `git push` can take a few minutes; run it in the background.
- Bump `version:` in `pubspec.yaml` for every new APK (patch number +1, build number +1).

## Security rules (always)

- Never touch the owner's separate "Zunft" Supabase project.
- The database password lives only in the git-ignored `.env.local` (`SUPABASE_DB_URL=...`). Never print, paste or commit it, and never ask the owner to paste it into chat.
- Only the publishable/anon key goes into the app. The service role key is used only inside Edge Functions, through their automatic environment.
- A Supabase access token (needed to deploy Edge Functions) is created by the owner only when needed. Afterwards, log the CLI out and remind them to revoke the token at supabase.com/dashboard/account/tokens.
- Gmail app passwords and the Firebase service account JSON go only into the Supabase dashboard, never into chat.
- Keep Supabase "Confirm email" switched on.
- Don't work around permission denials. Pen tests must never flood or DoS anything.
- `who649@haw-hamburg.de` is the platform admin.

## Build environment

Use Bash (Git Bash) with these variables:

```
export PUB_CACHE=D:/pub-cache GRADLE_USER_HOME=D:/gradle-home JAVA_HOME=D:/Android/jdk17 FLUTTER_ROOT=C:/src/flutter
F=/c/src/flutter/bin/flutter
```

| Task | Command |
|---|---|
| Regenerate translations after editing `lib/l10n/app_en.arb` / `app_de.arb` | `$F gen-l10n` |
| Analyze | `$F analyze` (only "info" messages are expected, no errors or warnings) |
| App tests | `$F test` (46 tests) |
| APK | `$F build apk --release` (5–7 minutes; run in the background), then copy `build/app/outputs/flutter-apk/app-release.apk` to `D:/UniHub_APK/UniHub-v<version>.apk` |
| Web build | `$F build web`, then serve `build/web` (e.g. `python -m http.server 8080 --bind 127.0.0.1`) |

How the owner runs the website themselves (PowerShell): `cd D:\UniHub_v0.2`, then `flutter run -d chrome`. Press `R` to reload and `q` to stop.

## Database (Supabase project ref `xwdaygcezdbneoubimgv`)

- Migrations are in `supabase/migrations/`, named `YYYYMMDDHHMMSS_name.sql`. The newest is `20261114000100_name_guard_definer.sql`. All of them have been applied to the live database.
- To apply a new migration:
  1. `PYTHONIOENCODING=utf-8 python tools/dbtool.py apply supabase/migrations/<file>.sql`
  2. `python tools/dbtool.py baseline <version>`
- To read data: `python tools/dbtool.py query "select ..."`.
- Security tests: `PYTHONIOENCODING=utf-8 python tools/security_tests.py`. 776 checks must pass. They run against the live database inside a transaction that is rolled back.
- **New functions and tables are not public by default.** Every new function needs `revoke all ... from public, anon, authenticated` plus explicit `grant`s. Then add it to `allowed_exec` in `tools/security_tests.py` (in the "[13] Privileges audit" section) if users may call it. New tables need RLS and appear in the `expected` table list there.
- New SECURITY DEFINER functions use `set search_path = ''` with fully qualified names.
- Background jobs use pg_cron. The jobs are `unihub-reminders`, `unihub-push-retry`, `unihub-notifications-cleanup`, `unihub-attendance-checks`, `unihub-purge-unconfirmed` (deletes sign-ups never confirmed after 20 minutes) and `unihub-review-prompts`.
- Notifications flow: a row in `public.notifications` → pg_net calls the `send-push` Edge Function → Firebase Cloud Messaging. Adding a notification kind needs four changes:
  - the `notifications_kind_check` constraint
  - the texts in `supabase/functions/send-push/index.ts`
  - `notificationText`/`_icon` in `lib/features/student/notifications_screen.dart`
  - the en and de ARB strings
- Edge Functions are `send-push` and `remove-user`. Deploy one after the owner logs in:
  ```
  npx --yes supabase@2.122.0 login
  npx --yes supabase@2.122.0 functions deploy <name> --project-ref xwdaygcezdbneoubimgv --no-verify-jwt --use-api
  npx --yes supabase@2.122.0 logout --yes
  ```

## App structure

- `lib/core/auth/user_role.dart` contains `AppState`, the single Provider ChangeNotifier holding all state and server calls.
  - Refresh methods drop results if the user signed out meanwhile (`_stillSignedInAs`).
  - Server calls use `.timeout(_requestTimeout)`.
- `lib/core/services/*_repository.dart` hold the Supabase calls. `lib/core/models/` holds the data classes.
- `lib/features/` is split into student, planner (organizer), admin, auth and shell. The shell has the top bar and navigation: a bottom bar on phones and a side rail at 600 px and wider.
- Texts must exist in both English and German (`lib/l10n/*.arb`).
- **Look ("ticket stub", chosen by the owner 2026-11-11):** events are drawn as tickets (`lib/core/widgets/ticket_stub.dart`, `EventStubCard`), with a category colour edge, a navy (`AppTheme.ink`) accent and Space Mono (`AppTheme.monoFamily`, `monoStyle`) for small labels. So far only the home and ticket screens use it; other screens follow once the owner approves. The wallpaper setting was removed on the owner's request.
- **PC layout:** the home screen shows tickets two per row from 680 px and adds a right column (`HomeSidePanel`: next ticket, saved events) from 1000 px. The side menu spells out its labels from 1100 px.
- **Wide-screen gotcha:** in a `Row`, don't give buttons a `Flexible` share. That pushes them into the middle on desktop. Use `ConstrainedBox(maxWidth: ...)` instead.
- Tests (`test/backend_flow_test.dart`) use a fake backend and `_settle(tester, rounds: n)`, where each round is about 100 ms. Calls with `.timeout()` need more rounds.

## Product rules decided by the owner

- Signed-out visitors may scroll public events but must sign in to open or register for any event. Campus events need an account with that university's email. Don't change this.
- **Reviews:**
  - They open when the event starts and are allowed only if the organizer enabled them.
  - At events with QR scanning, only scanned people can review. Those reviews are "verified": public and counted in the stars.
  - At events without scanning, anyone with a ticket may review in good faith. Those reviews are unverified: only the organizer sees them, and they don't count in the stars.
  - The owner confirmed this rule should stay as it is.
- "How was it?" review invitations go out about 1 hour after an event ends, once per person, only to people allowed to review.
- Admins can remove users and optionally block their email. Blocks can be lifted under "Blocked addresses". Removing a user also deletes their uploaded files.

## Documents

- `docs/UNIHUB_Testing_Guide.pdf` is the phone test plan, generated by `python tools/make_testing_guide.py`. Update it when features change. It is also copied to `D:\UniHub_APK`.
- `docs/UNIHUB_Security_Report.pdf` is the security report.
- `README.md` is outdated: it still describes the early mock-data prototype.

## Open items (as of 2026-11-09, version 0.2.16)

- **Hosting the website so the owner can send the school a link.**
  - Choose a host and a domain. HTTPS is required (the camera scanner needs it).
  - Add security headers.
  - Set up email sending from the domain (e.g. Resend or Brevo instead of Gmail).
- **Web push is not set up.** It needs a Firebase web app ID and VAPID key. Web users still get the in-app bell.
- **Later:**
  - profanity checking for reviews
  - Stripe for paid events (after the school approves)
  - an Android release signing key
  - a `mobile_scanner` upgrade
  - CI `actions/checkout@v5`
  - an addendum to the security report
  - about 72 deprecation infos from the analyzer
- **Pen tests need fresh throwaway accounts.** `tools/pentest/` expects `D:/tmp/pt_creds.json`, which no longer exists.
- **The owner hasn't run the testing guide yet.** After Test 28 (remove user), check that the user's photo was deleted from storage.

"""UniHub Testing Guide (phone edition, v0.2.14). Writes docs/UNIHUB_Testing_Guide.pdf."""
import shutil
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether

OUT = r"D:\UniHub_v0.2\docs\UNIHUB_Testing_Guide.pdf"
COPY = r"D:\UniHub_APK\UNIHUB_Testing_Guide.pdf"
VERSION = "0.2.14"

BLUE = colors.HexColor("#3F51E0")
INK = colors.HexColor("#12141C")
MUTED = colors.HexColor("#5B6070")
ss = getSampleStyleSheet()
T = ParagraphStyle("T", parent=ss["Title"], textColor=BLUE, fontSize=30, spaceAfter=6)
SUB = ParagraphStyle("SUB", parent=ss["Normal"], alignment=1, fontSize=13, textColor=MUTED)
H1 = ParagraphStyle("H1", parent=ss["Heading1"], textColor=BLUE, fontSize=18, spaceBefore=4, spaceAfter=6)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], textColor=INK, fontSize=12.5, spaceBefore=10, spaceAfter=3)
B = ParagraphStyle("B", parent=ss["BodyText"], fontSize=10.5, leading=15, textColor=INK)
STEP = ParagraphStyle("STEP", parent=B, spaceBefore=2, spaceAfter=2, leftIndent=14, firstLineIndent=-14)
C = ParagraphStyle("C", parent=B, fontSize=9.5, leading=12.5)
CB = ParagraphStyle("CB", parent=C, fontName="Helvetica-Bold")

def P(t, s=B): return Paragraph(t, s)
def k(t): return "<font face='Courier'>%s</font>" % t  # something to type
def b(t): return "<b>%s</b>" % t

def callout(kind, text):
    col = {"TIP": "#E6F4EA", "WARNING": "#FDECEA", "NOTE": "#E8F0FE"}[kind]
    edge = {"TIP": "#34A853", "WARNING": "#D93025", "NOTE": "#1A73E8"}[kind]
    t = Table([[P("<b>%s:</b> %s" % (kind.capitalize(), text), C)]], colWidths=[170 * mm])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(col)),
                           ("LINEBEFORE", (0, 0), (0, -1), 3, colors.HexColor(edge)),
                           ("LEFTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 5),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    return [Spacer(1, 3), t, Spacer(1, 5)]

def table(rows, widths):
    data = [[P(c, CB if i == 0 else C) for c in r] for i, r in enumerate(rows)]
    t = Table(data, colWidths=[w * mm for w in widths], repeatRows=1)
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                           ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EEF0FB")),
                           ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#CCCCCC")),
                           ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    return t

def result_box():
    """'[ ] OK   [ ] Problem: ______' drawn with real boxes (no special font characters)."""
    box = ""
    t = Table([[box, P("OK", C), box, P("Problem, what happened:", C), ""]],
              colWidths=[4 * mm, 12 * mm, 4 * mm, 48 * mm, 102 * mm], rowHeights=[5 * mm])
    t.setStyle(TableStyle([("BOX", (0, 0), (0, 0), 0.8, MUTED), ("BOX", (2, 0), (2, 0), 0.8, MUTED),
                           ("LINEBELOW", (4, 0), (4, 0), 0.5, MUTED),
                           ("LEFTPADDING", (1, 0), (1, 0), 4), ("LEFTPADDING", (3, 0), (3, 0), 4),
                           ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("TOPPADDING", (0, 0), (-1, -1), 0),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]))
    return t

N = [0]
def test(title, steps, expect, intro=None, after=None):
    """One test: number + title, steps, what you should see, result boxes."""
    N[0] += 1
    out = [P("Test %d - %s" % (N[0], title), H2)]
    if intro:
        out.append(P(intro, C))
    for i, s_ in enumerate(steps, 1):
        out.append(P("<b>%d.</b>&nbsp; %s" % (i, s_), STEP))
    out.append(P("<b>You should see:</b> " + expect, ParagraphStyle("E", parent=STEP, textColor=colors.HexColor("#137A50"))))
    out += [Spacer(1, 2), result_box(), Spacer(1, 4)]
    if after:
        out += after
    return [KeepTogether(out)]

s = []
# ------------------------------------------------------------------ cover
s += [Spacer(1, 30 * mm), P("UniHub", T), P("Testing Guide - on your phone", SUB),
      P("App version %s" % VERSION, SUB), Spacer(1, 8 * mm),
      P("Every test is a short list of taps with what you should see. Tick <b>OK</b> or <b>Problem</b> "
        "under each one. When you find a problem, write one line about it and send me the list "
        "(a screenshot helps a lot).", ParagraphStyle("c", parent=B, alignment=1)), Spacer(1, 8 * mm)]
s.append(table([
    ["Part", "What it covers", "Time"],
    ["1", "Install the app and get ready", "10 min"],
    ["2", "Signing up and signing in", "15 min + 25 min wait"],
    ["3", "The student side: feed, event page, tickets", "25 min"],
    ["4", "Becoming an organizer and creating events", "20 min"],
    ["5", "Notifications", "15 min + waiting"],
    ["6", "After the event: past tickets, reviews, statistics", "20 min"],
    ["7", "Admin tools", "20 min"],
    ["8", "Profile, looks and deleting an account", "15 min"],
    ["9", "If something goes wrong", "as needed"],
], [12, 118, 40]))
s += [Spacer(1, 6 * mm)]
s += callout("NOTE", "Words in " + k("this style") + " are things you type exactly. Words in <b>bold</b> are buttons "
             "or tabs you tap.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 1
s.append(P("Part 1 - Install the app and get ready", H1))
s.append(P("1A. Install the newest version", H2))
s.append(P("The newest app file is " + k("D:\\UniHub_APK\\UniHub-v%s.apk" % VERSION) + ". Ignore the older files in "
           "that folder."))
for i, t_ in enumerate([
        "Copy the file to your phone: USB cable (choose <b>File transfer</b> on the phone, copy it into "
        "<b>Download</b>) or Google Drive. Do not email it: Gmail blocks .apk files.",
        "On the phone open the <b>Files</b> app > <b>Downloads</b> and tap the file.",
        "If Android asks, allow installing from this source. If Play Protect warns you, tap <b>More details</b> > "
        "<b>Install anyway</b> (it does that for every app that is not from the Play Store).",
        "Tap <b>Install</b>. It updates the old UniHub and keeps you signed in. Only if it says "
        "<i>App not installed</i>: uninstall the old UniHub first, then install again."], 1):
    s.append(P("<b>%d.</b>&nbsp; %s" % (i, t_), STEP))
s.append(P("1B. The accounts in this guide", H2))
s.append(P("You play several people on one phone by signing out and in again. Gmail ignores everything between "
           "<b>+</b> and <b>@</b>, so all codes for the + addresses arrive in your normal inbox."))
s.append(table([
    ["Name in this guide", "Email", "Who it is"],
    ["<b>Admin</b>", "who649@haw-hamburg.de", "You, the platform admin (exists already)"],
    ["<b>Test Student</b>", "whp2718+student@gmail.com", "A normal user, created in Test 1"],
    ["<b>Student 2</b>", "whp2718+student2@gmail.com", "A second normal user, for the waitlist (Test 17)"],
    ["<b>Throwaway</b>", "whp2718+gone1@gmail.com, +gone2 ...", "Short-lived accounts for delete/remove tests"],
], [32, 62, 76]))
s += callout("TIP", "Write the passwords on paper. To <b>sign out</b>: tap your name at the top right > <b>Sign out</b>. "
             "To <b>sign in</b>: tap <b>Sign in / Sign up</b>, type email and password.")
s += callout("NOTE", "Some tests need a <b>second phone</b> (a friend's) or a <b>computer screen</b>. They say so at the "
             "top. Skip them if you can't do them now.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 2
s.append(P("Part 2 - Signing up and signing in", H1))
s += test("Create the Test Student account", [
    "Sign out. Tap <b>Sign in / Sign up</b> > <b>New here? Create an account</b>.",
    "Name " + k("Test Student") + ", email " + k("whp2718+student@gmail.com") + ", a password of 8+ characters.",
    "Under the email it says <i>No university email detected</i> (correct for Gmail). Tap <b>Create account</b>.",
    "Check the screen <b>Check your email</b>: it has one box, <b>Code from your email</b>, and a grey note that "
    "you have <b>20 minutes</b>.",
    "Type the 6-digit code from Gmail and tap <b>Verify</b>."],
    "you are signed in; the bottom bar shows <b>Home</b>, <b>My Tickets</b>, <b>Profile</b>.")
s += test("Unfinished sign-ups free the email again (needs a 25-minute wait)", [
    "Sign out. Start a sign-up with " + k("whp2718+ghost@gmail.com") + ", but <b>do not</b> type the code. "
    "Close the app.",
    "Do other tests for <b>25 minutes</b>. (The server deletes sign-ups whose code was never entered after "
    "20 minutes.)",
    "Sign up again with exactly the same email and any password.",
    "A <b>new</b> code email arrives. Type it in."],
    "the second sign-up works normally and you are signed in. Before this fix the email was stuck forever.")
s += test("Coming back before the 20 minutes are up", [
    "Sign out. Start a sign-up with " + k("whp2718+back@gmail.com") + " and close the app without the code.",
    "Within 20 minutes open the app and <b>sign in</b> with that email and password."],
    "the app sends a new code and opens the code screen by itself. Type it: you are in.")
s += test("Forgot password", [
    "Sign out. Tap <b>Sign in / Sign up</b> > <b>Forgot password?</b>",
    "Type " + k("whp2718+student@gmail.com") + " and tap <b>Send code</b>.",
    "Type the code from Gmail and a new password. Confirm."],
    "you are signed in with the new password. (Write it down!)")
s += test("Wrong password and too many codes", [
    "Sign out and sign in as Test Student with a wrong password.",
    "On the code screen of any sign-up, tap <b>Resend code</b> twice quickly."],
    "<i>Wrong email or password</i> for the first; for the second a message asks you to <b>wait a minute</b> "
    "before asking for another code.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 3
s.append(P("Part 3 - The student side", H1))
s.append(P("Sign in as <b>Test Student</b> for this part unless a test says otherwise."))
s += test("The home feed", [
    "Open <b>Home</b>. While it loads you briefly see grey pulsing cards (on a fast connection it is very short).",
    "At the top it greets you: <b>Hi Test</b>. Below: category chips, one big featured event, then "
    "<b>Coming up</b> with smaller rows.",
    "The cards fade in one after another. Press a card: it shrinks a little under your finger.",
    "Swipe the chip row left and tap <b>Other</b>: a list <b>More categories</b> opens. Tap <b>All</b> to go back.",
    "Tap the <b>magnifying glass</b>, type part of an event name. Then type " + k("zzz") + "."],
    "matching events stay; for zzz a drawn picture with <i>No events match your search</i>. Tap <b>X</b> to close.")
s += test("Saving events (heart)", [
    "Tap the <b>heart</b> on an event picture. Your phone gives a tiny vibration; the heart turns red.",
    "Tap the <b>heart at the top</b> (next to the magnifying glass): only saved events show.",
    "Close the app completely, open it again."],
    "the heart is still red (it is saved online). Tap the top heart again to see everything.")
s += test("The event page", [
    "Open any upcoming event.",
    "Check: date and place in small tiles, the organizer under <b>Hosted by</b>, a seat bar like "
    "<i>3 of 50 seats taken</i> (only for events with a limit).",
    "Tap the poster (or the arrows icon): the whole poster shows on black. Pinch to zoom, <b>X</b> to close.",
    "Tap <b>Add to calendar</b>: your calendar app opens with the event filled in. Go back without saving.",
    "If the event has <b>Contact &amp; links</b>, tap each one: browser, mail app, phone dialer."],
    "everything is readable in light and dark mode, nothing overlaps.")
s += test("Register: confetti, ticket and bright QR code", [
    "On an event that is <b>not</b> yours, tap <b>Register</b> at the bottom.",
    "Watch: confetti, a short vibration and the button turns into <b>Registered</b> with a tick.",
    "Open <b>My Tickets</b>. The ticket has a coloured header, the date and place, and a QR code.",
    "Tap the <b>QR code</b>."],
    "it opens full screen on white and the screen goes to <b>full brightness</b>. Close it with <b>X</b>: the "
    "brightness goes back to what it was.")
s += test("Cancel a registration", [
    "In <b>My Tickets</b> tap <b>Cancel registration</b> on that ticket > <b>Yes, cancel</b>."],
    "<i>Registration cancelled.</i> The ticket disappears. The event shows <b>Register</b> again.")
s.append(P("<b>Register again</b> for that event before you continue - the next parts use it.", C))
s.append(PageBreak())

# ------------------------------------------------------------------ part 4
s.append(P("Part 4 - Becoming an organizer and creating events", H1))
s += test("Apply to become an organizer", [
    "As <b>Test Student</b>: <b>Profile</b> > <b>Become an organizer</b>.",
    "Tap <b>Send request</b> straight away: red messages ask for position, phone and the tick box.",
    "Fill in club name " + k("Test Events Club") + ", position " + k("Chair") + ", phone " + k("+49 40 1234567") + ".",
    "Tap <b>Add document</b> and pick a photo or PDF (max 5 MB).",
    "Tick the box and tap <b>Send request</b>."],
    "<i>Request sent</i>; the Profile card says your request is waiting for review.")
s += test("Admin approves", [
    "Sign out, sign in as <b>Admin</b> > <b>Admin</b> tab > <b>Requests</b>.",
    "Check the request: position, phone (tap = dialer), email, and a chip <b>Document 1</b> (tap = opens it).",
    "Tap <b>Approve</b>.",
    "Sign out, sign in as <b>Test Student</b> > <b>Profile</b> > <b>Check status</b>."],
    "Test Student's bottom bar changes to <b>Dashboard</b>, <b>Create Event</b>, <b>Scanner</b>, <b>Profile</b>. "
    "In the Admin's Requests list the card now says documents were deleted.")
s += test("Create an event with everything", [
    "As <b>Test Student</b> (now an organizer): <b>Create Event</b>.",
    "Add a poster with <b>Add poster image</b>. Title " + k("Big Test Event") + ", location " + k("Room 1") + ".",
    "Set <b>Starts</b> to <b>2 days from now</b>. Turn off <b>No attendee limit</b> and set the capacity to "
    + k("20") + ".",
    "Check that the switch <b>Free unconfirmed seats</b> appears (it only shows when there is a seat limit). "
    "Leave it off.",
    "Categories: tap <b>Other</b> and type " + k("Yoga") + " in <b>Your own category</b>.",
    "Fill <b>Contact &amp; links</b>: website " + k("www.haw-hamburg.de") + ", an email, a phone.",
    "Choose <b>Public event</b> and tap <b>Publish Event</b>."],
    "<i>Event published.</i> It appears on the Dashboard. Watch the <b>Live Preview</b> update while you type.")
s += test("Edit an event and see 'Your event'", [
    "<b>Dashboard</b> > the <b>pencil</b> on Big Test Event. Change the title to " + k("Big Test Event 2") +
    " > <b>Save changes</b>.",
    "Tap your name > <b>Switch to student view</b>, open the event."],
    "<i>Event updated.</i> On your own event the button says <b>Your event</b> (grey). Switch back to the organizer "
    "view afterwards.")
s += test("Check in a guest with the scanner (needs a second phone or a computer screen)", [
    "As <b>Admin</b>, switch to student view and register for Big Test Event 2. Open <b>My Tickets</b>, tap the QR "
    "code so it is big.",
    "<b>Second phone:</b> sign in there as Test Student. <b>One phone only:</b> take a screenshot of the big QR, "
    "send it to your computer (e.g. WhatsApp Web) and open it on the computer screen. Then sign in as Test Student "
    "on your phone.",
    "As Test Student: <b>Scanner</b> > choose <b>Big Test Event 2</b> at the top > point the camera at the QR.",
    "Scan the same QR a second time."],
    "first a green <b>Access granted</b> with the name; the second time it says the guest <b>was already checked "
    "in</b>. The Admin's ticket then shows <b>CHECKED IN</b> (refresh My Tickets).")
s.append(PageBreak())

# ------------------------------------------------------------------ part 5
s.append(P("Part 5 - Notifications", H1))
s.append(P("Push messages go to the account that is <b>signed in on the phone</b>. Messages for other accounts are "
           "still waiting in their <b>bell</b> when you sign in as them."))
s += test("Allow push messages", [
    "Sign in as <b>Test Student</b>. If Android asks to allow notifications, tap <b>Allow</b>.",
    "<b>Profile</b> > the <b>Notifications</b> card."],
    "the card says <i>Push messages are on for this device.</i> (If it says blocked: phone Settings > Apps > "
    "UniHub > Notifications > on.)")
s += test("Waitlist: a seat opens up", [
    "As <b>Test Student</b> (organizer view): create an event " + k("Tiny Event") + " starting tomorrow, "
    "capacity " + k("1") + ", public.",
    "Sign in as <b>Admin</b> > student view > register for Tiny Event (you get the seat).",
    "Create <b>Student 2</b> (" + k("whp2718+student2@gmail.com") + ") and register for Tiny Event.",
    "Student 2 sees <b>Waitlisted</b>; in My Tickets: <b>ON WAITLIST</b>.",
    "Sign in as <b>Admin</b> > My Tickets > <b>Cancel registration</b> on Tiny Event.",
    "Sign in as <b>Student 2</b> and tap the <b>bell</b>."],
    "a notification <b>You got a spot!</b>; Student 2's My Tickets now has a real ticket with a QR code.")
s += test("Event changed / cancelled messages", [
    "Student 2 is registered for Tiny Event. Sign in as <b>Test Student</b>, edit Tiny Event and change the time.",
    "Then edit it again > <b>Cancel event</b> > <b>Yes, cancel event</b>.",
    "Sign in as <b>Student 2</b> and open the bell."],
    "<b>Event updated</b> and <b>Event cancelled</b>; the ticket in My Tickets is marked cancelled.")
s += test("Removing notifications", [
    "Still in the bell list: swipe one notification to the left or right.",
    "Tap the <b>bin icon</b> at the top > <b>Delete all</b>."],
    "the swiped one disappears; after Delete all the list shows a drawn picture with "
    "<i>No notifications yet.</i> Close and reopen: they stay gone.")
s += test("Reminder push (leave the phone signed in)", [
    "As <b>Test Student</b> register for an event (made by someone else) that starts in 3 to 20 hours.",
    "Stay signed in as Test Student. Wait a bit more than 1 hour."],
    "a push message <b>Reminder</b>: <i>... starts in N hours.</i>")
s += test("'Are you still coming?' (wait 12+ hours, or ask Claude to speed it up)", [
    "As <b>Test Student</b> register for an event (made by someone else) that starts in about <b>2 days</b>.",
    "Stay signed in. About 12 hours later a push <b>Still coming?</b> arrives.",
    "Open <b>My Tickets</b>: a card <b>Are you still coming?</b> sits above the ticket. Tap <b>Yes, I'm coming</b>."],
    "<i>Thanks! Your seat is confirmed.</i> and a green <b>Confirmed</b> badge on the ticket. (<b>I can't come</b> "
    "asks first, then frees the seat.)",
    after=callout("TIP", "Don't want to wait 12 hours? Tell me which event, and I can move the registration back in "
                  "time so the question arrives within 10 minutes."))
s.append(PageBreak())

# ------------------------------------------------------------------ part 6
s.append(P("Part 6 - After the event: past tickets, reviews, statistics", H1))
s.append(P("For these you need an event that has already started and ended. Create a short one now:"))
s += test("A short event that ends soon", [
    "As <b>Test Student</b> (organizer view): create " + k("Quick Event") + ". <b>Starts</b>: 5 minutes from now. "
    "<b>Ends</b>: 20 minutes from now. Turn <b>Require QR Code Check-in</b> off and leave <b>Allow User Reviews</b> on.",
    "Sign in as <b>Student 2</b> and register for Quick Event.",
    "Wait until it has ended (about 20 minutes)."],
    "Quick Event is published and Student 2 has a ticket.")
s += test("Past tickets fold away", [
    "As <b>Student 2</b> open <b>My Tickets</b> after Quick Event has ended.",
    "Scroll down to <b>Past events (1)</b> and tap it."],
    "upcoming tickets stay on top; Quick Event is now a small card in the folded <b>Past events</b> section with "
    "<b>ENDED</b> and a <b>Leave Review</b> button.")
s += test("Leave a review", [
    "Tap <b>Leave Review</b>, give 4 stars and a comment, tick the box that you attended, submit."],
    "a green message; the card now shows a gold star instead of the button (you can review once).")
s += test("Organizer statistics", [
    "Sign in as <b>Test Student</b> > <b>Dashboard</b>.",
    "Scroll down slowly. The top part (university name and <b>Event Analytics</b>) must stay solid: the cards slide "
    "<b>under</b> it, never through it - in light and dark mode.",
    "In <b>Registered, confirmed and came</b> each event has labelled rows <b>Registered</b>, <b>Confirmed</b>, "
    "<b>Came</b> with a number at the end. Events without sign-ups say <i>No sign-ups yet</i>; open events say "
    "<i>Came: not counted</i>.",
    "Tap an event (or a card under <b>Attendance by event</b>)."],
    "the <b>Event statistics</b> page: number tiles, labelled attendance bars, <b>Sign-ups per day</b> and, for "
    "Quick Event, the <b>Ratings</b> with Student 2's 4 stars.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 7
s.append(P("Part 7 - Admin tools", H1))
s.append(P("Sign in as <b>Admin</b> for this part."))
s += test("Reporting an event and handling the report", [
    "As <b>Student 2</b>: open an event made by Test Student > <b>three dots</b> (top right) > <b>Report event</b> > "
    "<b>Spam or advertising</b>, type " + k("test report") + " > <b>Send report</b>.",
    "Sign in as <b>Admin</b> > <b>Admin</b> > <b>Reports (1)</b>.",
    "Tap <b>Dismiss</b> > <b>Dismiss</b>."],
    "the report shows the event, reason and text; afterwards it says <b>Dismissed</b> and the event stays online.",
    after=callout("WARNING", "<b>Remove event</b> cancels an event for everyone and can't be undone. Only try it on an "
                  "event you made just for testing."))
s += test("Change someone's role", [
    "<b>Admin</b> > <b>Users</b>. Search " + k("Student 2") + ".",
    "Tap the <b>person-with-gear icon</b> on the card > <b>University organizer</b>. Then set it back to <b>Student</b>.",
    "Find your own card."],
    "the role line changes each time. Your own card has no gear icon (you can't lock yourself out).")
s += test("Remove a user, with photo and block", [
    "Create " + k("whp2718+gone1@gmail.com") + " (name " + k("Gone One") + "). As Admin give it the role "
    "<b>Commercial planner</b>.",
    "Sign in as Gone One > <b>Profile</b> > add a profile photo. Create one public event and publish it.",
    "Sign in as <b>Admin</b> > <b>Users</b> > gear icon on Gone One > <b>Remove user</b> (red).",
    "Read the dialog: it says <b>1 event</b> will be deleted too. Tick <b>Block this email address ...</b> and tap "
    "<b>Remove user</b>."],
    "<i>Gone One was removed</i>; the person and the event are gone from the lists. Tell me when you did this test "
    "and I will check that the photo file was deleted on the server too.")
s += test("A blocked address cannot sign up", [
    "Sign out. Try to sign up again with " + k("whp2718+gone1@gmail.com") + "."],
    "a message that this email address can't be used to sign up.")
s += test("Unblock an address", [
    "Sign in as <b>Admin</b> > <b>Users</b> > <b>Blocked addresses</b> (under the search box).",
    "The list shows whp2718+gone1@gmail.com with the date and your name. Tap <b>Unblock</b> > <b>Unblock</b>.",
    "Sign out and sign up with " + k("whp2718+gone1@gmail.com") + " again."],
    "<i>... is unblocked</i>, the list is empty, and the sign-up works (a brand-new, empty account).")
s += test("Unconfirmed label and safety rules", [
    "Start a sign-up with " + k("whp2718+gone2@gmail.com") + " but don't enter the code.",
    "Within 20 minutes, as <b>Admin</b> > <b>Users</b>, find it.",
    "Open the gear menu on an <b>admin</b> account (if there is another one)."],
    "the new account shows an orange <b>Email not confirmed</b>. Admin accounts have no <b>Remove user</b> item "
    "(they must be made a normal user first).")
s.append(PageBreak())

# ------------------------------------------------------------------ part 8
s.append(P("Part 8 - Profile, looks and deleting an account", H1))
s += test("Profile basics", [
    "<b>Profile</b> > <b>Edit name</b>, change it, <b>Save</b>.",
    "<b>Change password</b> (then change it back or write it down).",
    "<b>Language</b> > <b>Deutsch</b>. Look around, then switch back to <b>English</b>. Close and reopen the app."],
    "<i>Saved.</i>, <i>Password changed.</i>; the app turns German and back; the language is kept after reopening.")
s += test("Light, dark and wallpapers", [
    "<b>Profile</b>: switch between <b>Light</b>, <b>Dark</b> and <b>System</b>.",
    "Pick a few <b>wallpapers</b> (Waves, Aurora, ...) and look at Home and the Dashboard.",
    "In dark mode open My Tickets and an event page."],
    "light mode is calm and white; dark mode is near-black with neon-green buttons. Text is readable everywhere and "
    "nothing overlaps.")
s += test("App icon, splash screen and calm motion", [
    "Look at the UniHub icon on your home screen. Close the app completely and open it.",
    "Switch your phone to dark mode and open the app again.",
    "Phone Settings > Accessibility > turn on <b>Remove animations</b> (the name differs per phone). Open the app, "
    "register for something. Turn it off again afterwards."],
    "a blue icon with a white U and a green dot; a blue splash screen (near-black in dark mode). With animations "
    "removed, no confetti and no fading.")
s += test("Delete your own account (Throwaway)", [
    "Create " + k("whp2718+gone3@gmail.com") + ". Register for one event.",
    "<b>Profile</b> > scroll to the bottom > <b>Delete account</b>. Type " + k("DELETE") + " > <b>Delete forever</b>.",
    "Try to sign in with that email."],
    "you are signed out; signing in says <i>Wrong email or password</i>. (An account that still owns events gets a "
    "message to ask an admin instead.)")
s.append(PageBreak())

# ------------------------------------------------------------------ part 9
s.append(P("Part 9 - If something goes wrong", H1))
s.append(P("Find what you see in the left column. If it isn't there, send me: the test number, what you tapped and a "
           "screenshot."))
s.append(Spacer(1, 4))
s.append(table([
    ["What you see", "What to do"],
    ["Phone says <i>App not installed</i>", "Uninstall the old UniHub (long-press the icon > Uninstall), then install again."],
    ["Phone blocks the install", "Tap <b>Install anyway</b> and allow installs from the Files app."],
    ["No code email arrives", "Wait 2 minutes and check spam. You can ask for a new code once a minute. If you waited "
     "more than 20 minutes, just sign up again (Test 2)."],
    ["<i>That code is wrong or has expired</i>", "Use the newest email only. Tap <b>Resend code</b>."],
    ["<i>This email address can't be used to sign up</i>", "An admin blocked it. Unblock it in Admin > Users > Blocked "
     "addresses (Test 30)."],
    ["Events don't load / <i>Could not load</i>", "Check the phone's internet, pull down to refresh, or close and reopen "
     "the app."],
    ["No push messages", "Profile > Notifications card. If it says blocked: phone Settings > Apps > UniHub > "
     "Notifications > on. Remember: push goes only to the account signed in on this phone."],
    ["Scanner shows a black screen", "Camera permission: phone Settings > Apps > UniHub > Permissions > Camera > Allow."],
    ["Scanner says <i>not allowed to scan</i>", "Only the organizer of that event can check people in."],
    ["<b>Leave Review</b> is grey", "The event hasn't started yet, it needs a QR check-in first, or you already reviewed it."],
    ["<b>Remove user</b> says it failed", "Check the internet and try again. Admins can't be removed until their role is "
     "changed to a normal user."],
    ["<i>You still own events</i> when deleting your account", "Use a fresh Throwaway account, or ask an admin to "
     "remove the account (Test 28)."],
    ["Admin tab is missing", "Only admin accounts have it, in the organizer view: tap your name > <b>Switch to organizer "
     "view</b>."],
    ["Poster upload refused", "Use a JPG, PNG or WebP photo under 5 MB."],
], [58, 112]))
s.append(Spacer(1, 8))
s.append(P("Words explained", H2))
s.append(table([
    ["Word", "Meaning"],
    ["Organizer", "An approved account that may publish events and check guests in."],
    ["Waitlist", "A queue for full events. People move up automatically when someone cancels."],
    ["Push message", "A notification that pops up on the phone even when the app is closed."],
    ["Platform admin", "Can manage everything: requests, reports and all users. University admins only manage their "
     "own university."],
], [40, 130]))


def foot(c, d):
    c.saveState(); c.setFont("Helvetica", 8); c.setFillColor(colors.grey)
    c.drawString(20 * mm, 10 * mm, "UniHub Testing Guide - v%s" % VERSION)
    c.drawRightString(190 * mm, 10 * mm, "Page %d" % d.page)
    c.restoreState()

SimpleDocTemplate(OUT, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=18 * mm,
                  bottomMargin=18 * mm, title="UniHub Testing Guide").build(
    s, onFirstPage=lambda c, d: None, onLaterPages=foot)
shutil.copyfile(OUT, COPY)
print("ok, tests:", N[0])

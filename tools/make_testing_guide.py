"""UniHub Testing Guide (phone edition, v0.2.30). Writes docs/UNIHUB_Testing_Guide.pdf."""
import shutil
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether

OUT = r"D:\UniHub_v0.2\docs\UNIHUB_Testing_Guide.pdf"
COPY = r"D:\UniHub_APK\UNIHUB_Testing_Guide.pdf"
VERSION = "0.2.30"

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
HAW = "your friend's HAW address"
# ------------------------------------------------------------------ cover
s += [Spacer(1, 30 * mm), P("UniHub", T), P("Testing Guide - on your phone", SUB),
      P("App version %s" % VERSION, SUB), Spacer(1, 8 * mm),
      P("Every test is a short list of taps with what you should see. Tick <b>OK</b> or <b>Problem</b> "
        "under each one. When you find a problem, write one line about it and send me the list "
        "(a screenshot helps a lot).", ParagraphStyle("c", parent=B, alignment=1)), Spacer(1, 8 * mm)]
s.append(table([
    ["Part", "What it covers", "Time"],
    ["1", "Install the app and get ready", "10 min"],
    ["2", "Signing up and signing in", "20 min + 25 min wait"],
    ["3", "The student side: feed, event page, tickets", "25 min"],
    ["4", "Organizers: applying, creating events, campus events", "30 min"],
    ["5", "Notifications", "15 min + waiting"],
    ["6", "After the event: past tickets, reviews, statistics", "25 min"],
    ["7", "Admin: roles, reports and case files", "25 min"],
    ["8", "Admin: suspending, removing and blocking", "30 min"],
    ["9", "Teams: helpers who scan and edit", "30 min"],
    ["10", "The yearly check of university emails", "15 min"],
    ["11", "Profile, looks, the website on a PC, deleting an account", "20 min"],
    ["12", "If something goes wrong", "as needed"],
], [12, 118, 40]))
s += [Spacer(1, 6 * mm)]
s += callout("NOTE", "Words in " + k("this style") + " are things you type exactly. Words in <b>bold</b> are buttons "
             "or tabs you tap.")
s += callout("TIP", "<b>Already tested Parts 1 to 6 with an older version?</b> You do not need to start over. Install "
             "this version and redo only the tests marked <b>(changed)</b> or <b>(new)</b> in Parts 4 and 6, then "
             "continue with Part 7.")
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
    ["<b>HAW Student</b>", HAW, "A real university account. Created in Test 2. Later becomes a university organizer."],
    ["<b>Test Student</b>", "whp2718+student@gmail.com", "An account without a university. Later becomes a commercial planner."],
    ["<b>Student 2</b>", "whp2718+student2@gmail.com", "A second account without a university, for looking and reporting"],
    ["<b>Throwaway</b>", "whp2718+gone1@gmail.com, +gone2 ...", "Short-lived accounts for delete/remove tests"],
], [32, 62, 76]))
s += callout("WARNING", "Codes for the HAW address arrive in <b>your friend's inbox</b>, not yours. He has to send you "
             "the code each time (sign-up in Test 2, and the yearly check in Part 10). Codes run out after a short "
             "time, so do those tests when he is reachable.")
s += callout("NOTE", "<b>Only university accounts can register for events.</b> In this guide that is the "
             "<b>Admin</b> and <b>HAW Student</b>. The Gmail accounts can look at public events, report them and "
             "become organizers, but cannot get tickets.")
s += callout("TIP", "Write the passwords on paper. To <b>sign out</b>: tap your name at the top right > <b>Sign out</b>. "
             "To <b>sign in</b>: tap <b>Sign in / Sign up</b>, type email and password. If an account from an older "
             "round of testing still exists, just sign in instead of creating it.")
s += callout("NOTE", "Some tests need a <b>second phone</b> (a friend's) or a <b>computer screen</b>. They say so at the "
             "top. Skip them if you can't do them now.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 2
s.append(P("Part 2 - Signing up and signing in", H1))
s += test("Create the Test Student account (Gmail)", [
    "Sign out. Tap <b>Sign in / Sign up</b> > <b>New here? Create an account</b>.",
    "Name " + k("Test Student") + ", email " + k("whp2718+student@gmail.com") + ".",
    "Under the email it says <i>No university email detected</i> and that only university accounts can register "
    "for events (correct for Gmail).",
    "Type a password of 8+ characters. In <b>Password again</b> type something different and tap "
    "<b>Create account</b>: a red message says the two passwords are not the same. Correct it and tap again.",
    "Check the screen <b>Check your email</b>: it has one box, <b>Code from your email</b>, and a grey note that "
    "you have <b>20 minutes</b>.",
    "Type the 6-digit code from Gmail and tap <b>Verify</b>."],
    "you are signed in; the bottom bar shows <b>Home</b>, <b>My Tickets</b>, <b>Profile</b>.")
s += test("Create the HAW Student account (university email)", [
    "Sign out. <b>Sign in / Sign up</b> > <b>New here? Create an account</b>.",
    "Name " + k("HAW Student") + ", email: " + HAW + ", a password (twice).",
    "Under the email it now says <i>University account detected</i> with the university's name. Tap "
    "<b>Create account</b>.",
    "Ask your friend for the code from his HAW inbox, type it and tap <b>Verify</b>.",
    "Open <b>Profile</b> and find the row with the university's name."],
    "you are signed in. The university row has a green tick and says <i>Set automatically from your verified "
    "university email.</i>")
s += test("Looking around without an account", [
    "Sign out. On the sign-in screen tap <b>Browse events without an account</b>.",
    "Scroll the list. Tap any event.",
    "Tap <b>Not now</b>, then tap <b>Sign in / Sign up</b> at the top."],
    "you see <b>Public events</b> only (no campus events). Opening an event asks you to sign in first "
    "(<i>Sign in to see this event</i>).")
s += test("Unfinished sign-ups free the email again (needs a 25-minute wait)", [
    "Sign out. Start a sign-up with " + k("whp2718+ghost@gmail.com") + ", but <b>do not</b> type the code. "
    "Close the app.",
    "Do other tests for <b>25 minutes</b>. (The server deletes sign-ups whose code was never entered after "
    "20 minutes.)",
    "Sign up again with exactly the same email and any password.",
    "A <b>new</b> code email arrives. Type it in."],
    "the second sign-up works normally and you are signed in.")
s += test("Coming back before the 20 minutes are up", [
    "Sign out. Start a sign-up with " + k("whp2718+back@gmail.com") + " and close the app without the code.",
    "Within 20 minutes open the app and <b>sign in</b> with that email and password."],
    "the app sends a new code and opens the code screen by itself. Type it: you are in.")
s += test("Forgot password", [
    "Sign out. Tap <b>Sign in / Sign up</b> > <b>Forgot password?</b>",
    "Type " + k("whp2718+student@gmail.com") + " and tap <b>Send code</b>.",
    "Type the code from Gmail and a <b>new</b> password in both boxes. Confirm."],
    "you are signed in and a green message says <i>Your password was changed. You are signed in.</i> (Write it down!)")
s += test("Forgot password, but typing the old password", [
    "Sign out > <b>Forgot password?</b> > same email > <b>Send code</b> (wait a minute if it asks you to).",
    "Type the code and, in both boxes, the password the account <b>already has</b>. Confirm."],
    "no error. You are signed in and the message says <i>That is the password you already had, so nothing "
    "changed.</i>")
s += test("Wrong password and too many codes", [
    "Sign out and sign in as Test Student with a wrong password.",
    "On the code screen of any sign-up, tap <b>Resend code</b> twice quickly."],
    "<i>Wrong email or password</i> for the first; for the second a message asks you to <b>wait a minute</b> "
    "before asking for another code. (Both are meant to be like this. After very many wrong passwords in a few "
    "minutes the server also blocks further tries from your connection for a while.)")
s.append(PageBreak())

# ------------------------------------------------------------------ part 3
s.append(P("Part 3 - The student side", H1))
s.append(P("Sign in as <b>HAW Student</b> for this part unless a test says otherwise."))
s += test("The home feed (new ticket look)", [
    "Open <b>Home</b>. At the top it greets you: <b>Hi HAW</b>.",
    "Look at the events: each one is drawn like a <b>ticket</b>, with a coloured edge for its category and small "
    "typewriter-style labels for date and place.",
    "Swipe the chip row left and tap <b>Other</b>: a list of more categories opens. Tap <b>All</b> to go back.",
    "Tap the <b>magnifying glass</b>, type part of an event name. Then type " + k("zzz") + "."],
    "matching events stay; for zzz a message that no events match your search. Tap <b>X</b> to close the search.")
s += test("Saving events (heart)", [
    "Tap the <b>heart</b> on an event. The heart turns red.",
    "Tap the <b>heart at the top</b> (next to the magnifying glass): only saved events show.",
    "Close the app completely, open it again."],
    "the heart is still red (it is saved online). Tap the top heart again to see everything.")
s += test("The event page and the poster", [
    "Open any upcoming event that has a poster.",
    "Check that you see the <b>whole poster</b>, not a cut-off part of it.",
    "Check: the <b>heart sits next to the event title</b> (not in the top corner), date and place, the organizer "
    "under <b>Hosted by</b>, a small line <b>POSTED ON</b> with the date the event was created, and for events "
    "with a limit a line like <i>3 of 50 seats taken</i>.",
    "Tap the poster: it <b>grows smoothly</b> to full size and the page behind it turns <b>frosted</b> (blurred), "
    "not black. Pinch to zoom. Tap outside or <b>Close</b>.",
    "If the event has <b>Contact &amp; links</b>, tap each one: browser, mail app, phone dialer."],
    "everything is readable in light and dark mode, nothing overlaps, and there is no separate 'enlarge' button "
    "in the top corner any more.")
s += test("Register: ticket and bright QR code", [
    "On an event that is <b>not</b> yours, tap <b>Register</b> at the bottom.",
    "The button turns into <b>Registered</b>.",
    "Open <b>My Tickets</b>. The ticket shows the date, the place and a QR code.",
    "Tap the <b>QR code</b>."],
    "it opens full screen on white and the screen goes to <b>full brightness</b>. Close it: the brightness goes "
    "back to what it was.")
s += test("Accounts without a university email can look, but not register", [
    "Sign in as <b>Student 2</b> (Gmail; create it now if needed). Open any public event.",
    "Look at the bar at the bottom of the event page.",
    "Open <b>Profile</b> and read the university row."],
    "the bar says <b>University accounts only</b> with the explanation that only accounts with a university email "
    "can register; the button is grey. The profile row says the same. Saving with the heart and reporting still "
    "work.")
s += test("Cancel a registration", [
    "In <b>My Tickets</b> tap <b>Cancel registration</b> on that ticket > <b>Yes, cancel</b>."],
    "<i>Registration cancelled.</i> The ticket disappears. The event shows <b>Register</b> again.")
s.append(P("<b>Register again</b> for that event before you continue - the next parts use it.", C))
s.append(PageBreak())

# ------------------------------------------------------------------ part 4
s.append(P("Part 4 - Organizers: applying, creating events, campus events", H1))
s += test("A Gmail account can only apply for public events", [
    "As <b>Test Student</b>: <b>Profile</b> > <b>Become an organizer</b>.",
    "Look at the two choices at the top. <b>University organizer</b> is grey with the note <i>You need a "
    "university email address to become a university organizer.</i> <b>Commercial / public events</b> is selected.",
    "Tap <b>Send request</b> straight away: red messages ask for position, phone and the tick box.",
    "Fill in club name " + k("Test Events Club") + ", position " + k("Chair") + ", phone " + k("+49 40 1234567") + ".",
    "Tap <b>Add document</b> and pick a photo or PDF (max 5 MB).",
    "Tick the box and tap <b>Send request</b>."],
    "<i>Request sent</i>; the Profile card says your request is waiting for review.")
s += test("The HAW account applies as a university organizer", [
    "Sign in as <b>HAW Student</b> > <b>Profile</b> > <b>Become an organizer</b>.",
    "This time <b>University organizer</b> can be chosen. Leave it selected.",
    "Fill in club name " + k("HAW Test Club") + ", position " + k("Member") + ", phone " + k("+49 40 7654321") +
    ", tick the box, <b>Send request</b>."],
    "<i>Request sent</i>.")
s += test("Admin approves both (with the 'permanent address' box)", [
    "Sign in as <b>Admin</b> > <b>Admin</b> tab > <b>Requests</b>.",
    "On Test Events Club check: position, phone (tap = dialer), email, and a chip <b>Document 1</b> (tap = opens it). "
    "Tap <b>Approve</b>. The dialog has only the note box. Tap <b>Approve</b>.",
    "On HAW Test Club tap <b>Approve</b>. This dialog also has a tick box <b>Permanent address of an organization "
    "(not a person): no yearly email check</b>. <b>Leave it empty</b> (your friend is a person, not an office). "
    "Tap <b>Approve</b>.",
    "Sign in as <b>HAW Student</b> and simply <b>wait up to half a minute</b> on any screen. Do not reload.",
    "Sign in as <b>Test Student</b>: the organizer tools are already there."],
    "for HAW Student, a green message <i>Your organizer request was approved...</i> appears by itself and the "
    "bottom bar changes to <b>Dashboard</b>, <b>Create Event</b>, <b>Scanner</b>, <b>Profile</b>. "
    "The tick box only appears for university organizers, never for commercial ones.")
s += test("Create a public event with everything", [
    "As <b>Test Student</b> (now a commercial planner): <b>Create Event</b>.",
    "Add a poster with <b>Add poster image</b>. Title " + k("Big Test Event") + ", location " + k("Room 1") + ".",
    "Set <b>Starts</b> to <b>2 days from now</b>. Turn off <b>No attendee limit</b>. The capacity is now a "
    "<b>number box</b> (no slider): type " + k("20") + ".",
    "Clear the box and type " + k("0") + ": a red message asks for a number from 1 upwards. Type " + k("20") + " again.",
    "Check that the switch <b>Free unconfirmed seats</b> appears (it only shows when there is a seat limit). "
    "Leave it off.",
    "Categories: keep <b>Sports</b> selected, tap <b>Other</b> and type " + k("Yoga, Gaming, Chess") + " in "
    "<b>Your own categories</b>. A red message under the box explains: that makes 4 categories (1 selected above "
    "plus 3 of your own), an event can have 3 in total. Remove one so it reads " + k("Yoga, Gaming") + ".",
    "Fill <b>Contact &amp; links</b>: website " + k("www.haw-hamburg.de") + ", an email, a phone.",
    "Tap <b>Publish Event</b>."],
    "<i>Event published.</i> It appears on the Dashboard. Watch the <b>Live Preview</b> update while you type.")
s += test("A campus event only the university can see", [
    "Sign in as <b>HAW Student</b> (organizer view) > <b>Create Event</b>.",
    "Title " + k("HAW Only Event") + ", location " + k("Campus") + ", starts in 3 days.",
    "Choose <b>Official university event</b> (it says only members of the university can see it). Publish.",
    "Sign in as <b>Admin</b> (a HAW address) > student view > <b>Home</b>: look for HAW Only Event.",
    "Sign in as <b>Student 2</b> (Gmail) > <b>Home</b>: look for it again.",
    "Sign out and tap <b>Browse events without an account</b>: look for it once more."],
    "the Admin sees HAW Only Event. The Gmail accounts and the visitor do <b>not</b> see it; they still see "
    "Big Test Event.")
s += test("Edit an event; the seat limit cannot go below the sign-ups", [
    "As <b>Test Student</b>: <b>Dashboard</b> > the <b>pencil</b> on Big Test Event. Change the title to "
    + k("Big Test Event 2") + " > <b>Save changes</b>.",
    "Sign in as <b>HAW Student</b> and as <b>Admin</b> (both in student view: tap your name > <b>Switch to "
    "student view</b>) and register for Big Test Event 2 with both.",
    "As <b>Test Student</b> edit the event again and set the capacity to " + k("1") + " > <b>Save changes</b>.",
    "Set it back to " + k("20") + " and save. Then tap your name > <b>Switch to student view</b> and open the event."],
    "the first save says <i>Event updated.</i> Capacity 1 is refused: <i>2 people are already registered. The limit "
    "cannot be lower than that.</i> On your own event the button says <b>Your event</b> (grey).")
s += test("Check in a guest with the scanner (needs a second phone or a computer)", [
    "<b>Phone A</b> (or the website on a computer): sign in as <b>Admin</b>, student view, <b>My Tickets</b>, tap "
    "the QR code of Big Test Event 2 so it is big. Leave it open.",
    "<b>Phone B</b>: sign in as <b>Test Student</b> > <b>Scanner</b> > choose <b>Big Test Event 2</b> at the top > "
    "point the camera at the QR.",
    "Watch <b>Phone A</b> for a few seconds without touching it.",
    "Scan the same QR a second time (take a screenshot of it beforehand if you want to try this)."],
    "the scanner shows a green <b>Access granted</b> with the name. Within a few seconds Phone A turns <b>green</b> "
    "by itself: <b>Checked in</b>. The second scan says the guest <b>was already checked in</b>.")
s += test("The scanner only lists events you can still scan for", [
    "As <b>Test Student</b> open <b>Scanner</b> and tap the event box at the top."],
    "only events <b>with QR check-in</b> that are running or still to come (plus ones that ended in the last few "
    "hours). No cancelled events, no old ones, and no open-entry events.")
s += test("(new) An event without QR check-in has no QR code", [
    "As <b>Test Student</b> create " + k("Open Door Event") + " in 3 days and turn <b>Require QR Code Check-in</b> "
    "<b>off</b>. Publish.",
    "Sign in as <b>HAW Student</b> (student view), register for it and open <b>My Tickets</b>.",
    "As <b>Test Student</b> open <b>Scanner</b> and look for Open Door Event in the event box."],
    "the ticket shows <b>Open entry</b> and <i>Nothing is scanned at this event. This ticket is your "
    "registration; just come along.</i> There is <b>no QR code</b>. The event is not in the scanner's list.")
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
    "Sign in as <b>HAW Student</b> > student view > register for Tiny Event.",
    "HAW Student sees <b>Waitlisted</b>; in My Tickets: <b>ON WAITLIST</b>.",
    "Sign in as <b>Admin</b> > My Tickets > <b>Cancel registration</b> on Tiny Event.",
    "Sign in as <b>HAW Student</b> and tap the <b>bell</b>."],
    "a notification <b>You got a spot!</b>; HAW Student's My Tickets now has a real ticket with a QR code.")
s += test("Event changed / cancelled messages", [
    "HAW Student is registered for Tiny Event. Sign in as <b>Test Student</b>, edit Tiny Event and change the time.",
    "Sign in as <b>HAW Student</b>: open the bell, then <b>My Tickets</b>.",
    "As <b>Test Student</b> edit it again > <b>Cancel event</b> > <b>Yes, cancel event</b>.",
    "Sign in as <b>HAW Student</b> and open the bell."],
    "after the change: <b>Event updated</b>, and the ticket shows the <b>new time</b>. After cancelling: "
    "<b>Event cancelled</b>, and the ticket is marked cancelled.")
s += test("Changes show up without reloading", [
    "<b>Needs two devices</b> (a second phone, or the website on a computer).",
    "Device A: sign in as <b>HAW Student</b>, register for one of Test Student's events and stay on <b>My Tickets</b>.",
    "Device B: sign in as <b>Test Student</b>, edit that event and change its time. Save.",
    "Do not touch device A. Wait up to half a minute.",
    "On device A pull the <b>Home</b> list and the <b>My Tickets</b> list down with your finger."],
    "device A shows the new time by itself (the app asks the server every 20 seconds and whenever you come back "
    "to it). Pulling down shows the round loading circle and refreshes at once. If pulling down does nothing on a "
    "screen, write down which screen.")
s += test("Removing notifications", [
    "Still in the bell list: swipe one notification to the left or right.",
    "Tap the <b>bin icon</b> at the top > <b>Delete all</b>."],
    "the swiped one disappears; after Delete all the list is empty. Close and reopen: they stay gone.")
s += test("Reminder push (leave the phone signed in)", [
    "As <b>HAW Student</b> register for an event that starts in 3 to 20 hours.",
    "Stay signed in as HAW Student. Wait a bit more than 1 hour."],
    "a push message <b>Reminder</b>: <i>... starts in N hours.</i>")
s += test("'Are you still coming?' (wait 12+ hours, or ask Claude to speed it up)", [
    "As <b>HAW Student</b> register for an event that starts in about <b>2 days</b>.",
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
    "Sign in as <b>HAW Student</b> (student view) and register for Quick Event. Do the same as <b>Admin</b>.",
    "Wait until it has ended (about 20 minutes)."],
    "Quick Event is published and both have a ticket.")
s += test("Past tickets fold away, and only for 90 days", [
    "As <b>HAW Student</b> open <b>My Tickets</b> after Quick Event has ended.",
    "Scroll down to <b>Past events (...)</b> and tap it."],
    "upcoming tickets stay on top; Quick Event is a small card in the folded <b>Past events</b> section with a "
    "<b>Leave Review</b> button. A small note says <i>Past events stay here for 90 days.</i> (After 90 days they "
    "leave this list; nothing is deleted.)")
s += test("(changed) Leave a review at an event without check-in", [
    "On Quick Event's past ticket tap <b>Leave Review</b>. Read the grey note: this event had no check-in, please "
    "review only if you were really there; the review is public and counts in the stars.",
    "Give 4 stars and a comment, tick the box that you attended, <b>Submit Review</b>."],
    "a green message; the card now shows that the review was submitted (you can review once). The stars count for "
    "the event although nobody was scanned (you see them in the dashboard test below).")
s += test("'How was it?' invitation (about 1 hour after the end)", [
    "Stay signed in as <b>Admin</b>, who had a ticket for Quick Event and has <b>not</b> reviewed it yet.",
    "About one hour after the event ended, look at the phone and the bell."],
    "a message <b>How was it?</b> Tapping it opens the review form for that event. It comes only once.")
s += test("(changed) Organizer dashboard: one list, reviews inside each event", [
    "Sign in as <b>Test Student</b> > <b>Dashboard</b>.",
    "Scroll down slowly. The top part must stay solid: the cards slide <b>under</b> it, never through it - in light "
    "and dark mode.",
    "Find <b>YOUR EVENTS</b>. There is only <b>one</b> list. Each event shows bars for <b>Registered</b>, "
    "<b>Confirmed</b> and <b>Came</b> (or <i>No sign-ups yet</i>). There are <b>no review lists</b> on the "
    "dashboard any more.",
    "Tap <b>Quick Event</b> and scroll to the bottom of its page."],
    "the <b>Event statistics</b> page: number tiles, attendance bars, <b>SIGN-UPS PER DAY</b>, the stars, and a "
    "section <b>REVIEWS</b> with HAW Student's 4-star review. With more than 20 reviews a button <b>Show more "
    "reviews</b> appears.")
s += test("(new) Publish a cancelled event again", [
    "As <b>Test Student</b> on the <b>Dashboard</b>, find <b>Tiny Event</b> (cancelled in Part 5). It now has a "
    "<b>pencil</b> as well as a red bin.",
    "Tap the pencil. Set a new start time in the future. The button at the bottom says <b>Publish again</b>. Tap it.",
    "Read the dialog (old sign-ups do not come back) and tap <b>Publish again</b>.",
    "Sign in as <b>HAW Student</b>: look for Tiny Event on <b>Home</b> and in <b>My Tickets</b>."],
    "<i>Event published.</i> Tiny Event is online again with the new time. HAW Student sees it on Home with a "
    "<b>Register</b> button; the old ticket is gone, so they register again if they want to come.")
s += test("(changed) Delete a cancelled event", [
    "As <b>Test Student</b> open Tiny Event with the pencil > <b>Cancel event</b> > <b>Yes, cancel event</b>.",
    "On the <b>Dashboard</b> tap the red <b>bin icon</b> on Tiny Event. Published events have none.",
    "Read the warning > <b>Delete event</b>."],
    "<i>Event deleted.</i> It is gone from the dashboard, together with its sign-ups, tickets and reviews. (An "
    "event with reports an admin has not decided yet cannot be deleted or published again; the app says so.)")
s.append(PageBreak())

# ------------------------------------------------------------------ part 7
s.append(P("Part 7 - Admin: roles, reports and case files", H1))
s += test("University roles only for university emails", [
    "Sign in as <b>Admin</b> > <b>Admin</b> > <b>Users</b>. Search " + k("Student 2") + " (a Gmail account).",
    "Tap the <b>person-with-gear icon</b> on the card and read the menu.",
    "Close it. Search <b>HAW Student</b> and open the same menu.",
    "Find your own card."],
    "for the Gmail account the menu has <b>no</b> <i>University organizer</i> and no <i>University admin</i>, and a "
    "grey line says <i>University roles need an account with a university email.</i> For HAW Student both roles are "
    "there. Your own card has no gear icon (you can't lock yourself out).")
s += test("Change someone's role (with a confirmation)", [
    "On <b>Student 2</b>: gear icon > <b>Commercial planner</b>.",
    "A dialog <b>Change role?</b> opens: it names the person, their email, <i>from Member to Commercial planner</i> "
    "and says in one sentence what the new role allows. Tap <b>Cancel</b> once and check that nothing changed.",
    "Do it again and tap <b>Change role</b>. Then set it back to <b>Member</b> the same way (the basic role is "
    "called Member for accounts without a university, Student for university accounts).",
    "On <b>HAW Student</b> pick <b>University admin</b> and look at the dialog, then tap <b>Cancel</b>."],
    "a role never changes with one tap. After confirming, a message says the role was changed and the line under "
    "the name is updated. For the two admin roles the confirm button is <b>red</b>.")
s += test("Several people report the same organizer", [
    "As <b>Test Student</b> (organizer view) create a second public event " + k("Second Test Event") + " in 4 days.",
    "Sign in as <b>Student 2</b>: open <b>Big Test Event 2</b> > <b>three dots</b> (top right) > <b>Report event</b> > "
    "<b>Spam or advertising</b>, type " + k("test report one") + " > <b>Send report</b>.",
    "Still as Student 2: report <b>Second Test Event</b> with <b>Wrong or misleading information</b>.",
    "Sign in as <b>HAW Student</b> (student view): report <b>Big Test Event 2</b> with <b>Scam or fake event</b>, "
    "text " + k("test report two") + ".",
    "Try to report the same event again as HAW Student."],
    "each report says <i>Thank you. An admin will look at it.</i> The repeat says <i>You already reported this "
    "event.</i>")
s += test("Reports are stacked by organizer", [
    "Sign in as <b>Admin</b> > <b>Admin</b> > <b>Reports (3)</b>.",
    "Look at the card for <b>Test Student</b>."],
    "<b>one</b> card for the organizer with an orange <b>3 open</b> and the line <b>3 REPORTS ON 2 EVENTS</b>. Inside: "
    "Big Test Event 2 with its two reports, Second Test Event with one. You never see <b>who</b> reported. The card "
    "has a button <b>Suspend organizer</b> (used in Part 8).")
s += test("Dismiss the reports of one event", [
    "Under <b>Second Test Event</b> tap <b>Dismiss</b> > <b>Dismiss</b>."],
    "<i>Report dismissed.</i> That event now says <b>Dismissed</b> and stays online. The card shows <b>2 open</b>.")
s += test("Remove a reported event and find the case file", [
    "Under <b>Big Test Event 2</b> tap the red <b>Remove event</b>. Read the warning, type the reason "
    + k("Test: advertising only") + " and tap <b>Remove event</b>.",
    "At the top right of the Reports tab tap <b>Case files</b>.",
    "Tap the entry <b>Big Test Event 2</b> to open it. Tap <b>Copy as text</b> and paste it into a note or WhatsApp."],
    "<i>Event removed.</i> Both reports about it are closed in one go. The case file says <b>Event removed</b>, "
    "<b>2 reports</b>, names the organizer and their email, your reason, and lists both reports with reason, text "
    "and time - but not who sent them. The pasted text contains the same.",
    after=callout("WARNING", "<b>Remove event</b> cancels an event for everyone and can't be undone. Only use it on "
                  "events you made for testing."))
s += test("Remove a review (admin)", [
    "As <b>Admin</b> open the <b>Dashboard</b>, tap <b>Quick Event</b> and scroll to <b>REVIEWS</b>.",
    "Tap the red <b>bin</b> next to HAW Student's review > <b>Remove review</b>."],
    "<i>Review removed.</i> It is gone from the list and no longer counts in the stars. (Only admins see the bin.)")
s.append(PageBreak())

# ------------------------------------------------------------------ part 8
s.append(P("Part 8 - Admin: suspending, removing and blocking", H1))
s.append(P("Suspending is the step <b>before</b> removing: it can be undone. Use it while you look into reports."))
s += test("Suspend an organizer (a reason is required)", [
    "First sign in as <b>HAW Student</b> (student view) and register for <b>Second Test Event</b> (so somebody "
    "holds a ticket).",
    "Sign in as <b>Admin</b> > <b>Admin</b> > <b>Reports</b> > on Test Student's card tap <b>Suspend organizer</b>.",
    "Read the dialog. The orange <b>Suspend</b> button is <b>grey</b> while the reason box is empty.",
    "Type " + k("Test: checking three reports") + " and tap <b>Suspend</b>.",
    "Open <b>Users</b> and find Test Student."],
    "<i>Test Student is suspended</i>. The report card shows a red <b>Suspended</b> label and the button now says "
    "<b>Reinstate</b>. In Users the line under the name ends with a red <b>Suspended</b>.")
s += test("What everyone else sees during a suspension", [
    "Sign in as <b>Student 2</b> > <b>Home</b>: look for Second Test Event.",
    "Sign out > <b>Browse events without an account</b>: look for it again.",
    "Sign in as <b>HAW Student</b> (who has a ticket for it) and open <b>My Tickets</b>."],
    "Test Student's events are <b>gone from the feed</b> for other people and for visitors. Tickets people already "
    "have are still there.")
s += test("What the suspended organizer sees", [
    "Sign in as <b>Test Student</b>.",
    "Look at the top of the app, then tap the <b>bell</b>.",
    "In organizer view open <b>Create Event</b> and try to publish a new event.",
    "On the <b>Dashboard</b> try to delete a cancelled event, if there is one."],
    "a <b>yellow bar</b> written for organizers: <i>... your events are hidden, and you cannot publish, edit or "
    "scan. Nothing has been deleted.</i> The bell has <b>Account suspended</b> (also as a push message). Publishing "
    "and deleting are refused.")
s += test("Reinstate, and the record of it", [
    "Sign in as <b>Admin</b> > <b>Admin</b> > <b>Users</b> > gear icon on Test Student > <b>Reinstate</b>.",
    "Type " + k("Test: reports were unfounded") + " (optional) and tap <b>Reinstate</b>.",
    "Open <b>Reports</b> > <b>Case files</b>.",
    "Sign in as <b>Test Student</b>, or just wait half a minute if it is open on another device. Check "
    "<b>Home</b> as Student 2."],
    "<i>Test Student is reinstated</i>. The case files have two new entries: <b>User suspended</b> (orange, with "
    "your reason and the reports) and <b>User reinstated</b> (green). For Test Student the yellow bar is gone and "
    "the bell says <b>Account reinstated</b>. The events are back in the feed.")
s += test("Suspending a student, and the safety rules", [
    "As <b>Admin</b> > <b>Users</b>: open the gear menu on another <b>admin</b> account, if there is one.",
    "Suspend <b>HAW Student</b> (any reason). Open the gear menu again and try to give the account another "
    "publishing role.",
    "Sign in as <b>HAW Student</b>: read the yellow bar, then in student view try to <b>Register</b> for an event.",
    "Sign in as <b>Admin</b> and <b>Reinstate</b> HAW Student."],
    "admin accounts have no <b>Suspend</b> and no <b>Remove user</b> item. Changing the role of a suspended account "
    "fails with a red message. HAW Student's yellow bar is the one for students (<i>... cannot register for events, "
    "write reviews or report events. Tickets you already have stay valid.</i>) and registering says <i>Your account "
    "is suspended, so this is not possible right now.</i>")
s += test("Remove a user, with photo and block", [
    "Create " + k("whp2718+gone1@gmail.com") + " (name " + k("Gone One") + "). As Admin give it the role "
    "<b>Commercial planner</b>.",
    "Sign in as Gone One > <b>Profile</b> > add a profile photo. Create one public event and publish it.",
    "Sign in as <b>Admin</b> > <b>Users</b> > gear icon on Gone One > <b>Remove user</b> (red).",
    "Read the dialog: it says <b>1 event</b> will be deleted too. Tick <b>Block this email address from signing up "
    "again</b> and tap <b>Remove user</b>.",
    "Open <b>Reports</b> > <b>Case files</b>."],
    "<i>Gone One was removed</i>; the person and the event are gone from the lists. The case files have a new entry "
    "<b>User removed</b> with <b>Address blocked</b>; it says nobody had reported this account. Tell me when you did "
    "this test and I will check that the photo file was deleted on the server too.")
s += test("A blocked address cannot sign up", [
    "Sign out. Try to sign up again with " + k("whp2718+gone1@gmail.com") + "."],
    "a message that this email address can't be used to sign up.")
s += test("Unblock an address", [
    "Sign in as <b>Admin</b> > <b>Users</b> > <b>Blocked addresses</b> (under the search box).",
    "The list shows whp2718+gone1@gmail.com with the date and your name. Tap <b>Unblock</b> > <b>Unblock</b>.",
    "Sign out and sign up with " + k("whp2718+gone1@gmail.com") + " again."],
    "<i>... is unblocked</i>, the list is empty, and the sign-up works (a brand-new, empty account).")
s += test("Unconfirmed label", [
    "Start a sign-up with " + k("whp2718+gone2@gmail.com") + " but don't enter the code.",
    "Within 20 minutes, as <b>Admin</b> > <b>Users</b>, find it."],
    "the new account shows an orange <b>Email not confirmed</b>.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 9
s.append(P("Part 9 - Teams: helpers who scan and edit", H1))
s.append(P("An organizer can invite other accounts to help: to <b>scan tickets</b> at the door, to <b>create and edit "
           "events</b>, or both. The events stay the organizer's. In this part <b>Test Student</b> (commercial "
           "planner) is the organizer and <b>Student 2</b> the helper. Two devices make it much easier."))
s += test("Invite a helper", [
    "Sign in as <b>Test Student</b> > <b>Profile</b> > <b>Team</b>.",
    "Under <b>MY TEAM</b> type " + k("whp2718+student2@gmail.com") + ". Leave <b>Scan tickets</b> ticked, leave "
    "<b>Create and edit events</b> empty. Tap <b>Send invitation</b>.",
    "Now type an address that has no account, e.g. " + k("nobody12345@gmail.com") + ", and send again.",
    "Untick both boxes."],
    "both times the same message: <i>If this address has a UniHub account that can join your team, it now has an "
    "invitation.</i> (On purpose: the box does not reveal who has an account.) Only Student 2 appears in the list, "
    "with an orange <b>Invited</b> label and <b>1 OF 15 PEOPLE</b>. With both boxes empty the button is grey.")
s += test("Accept the invitation", [
    "Sign in as <b>Student 2</b>. Tap the <b>bell</b>: there is a <b>Team invitation</b> from Test Student. Tap it.",
    "(Or: <b>Profile</b> > the Team row, which shows <b>1 team invitation</b>.)",
    "Under <b>TEAMS I HELP</b> tap <b>Accept</b>."],
    "<i>You joined the team.</i> The card now shows <b>SCAN TICKETS</b>, a <b>Scan tickets</b> button and "
    "<b>Leave team</b>. There is no <b>Events</b> button, because that permission was not given.")
s += test("Scan as a helper (needs a second device)", [
    "As <b>Test Student</b> make sure there is an upcoming event <b>with</b> QR check-in, e.g. Second Test Event.",
    "Device A: sign in as <b>HAW Student</b> (student view), register for that event, open the big QR code.",
    "Device B: sign in as <b>Student 2</b> > <b>Profile</b> > <b>Team</b> > <b>Scan tickets</b>. The title names "
    "Test Student; the event box lists only Test Student's events. Scan the code.",
    "Sign in as <b>Test Student</b> > <b>Dashboard</b> > scroll to the recent scans."],
    "Student 2 gets the green <b>Access granted</b>; device A turns green. The organizer's dashboard shows the scan. "
    "Student 2 has <b>no</b> dashboard, guest list or statistics of Test Student.")
s += test("Give the helper the right to edit", [
    "As <b>Test Student</b> > <b>Profile</b> > <b>Team</b>: on Student 2's card tap the chip <b>Create and edit "
    "events</b> so it is selected.",
    "Try to switch <b>both</b> chips off."],
    "the chip is selected at once. The last remaining chip cannot be switched off (remove the person instead).")
s += test("Create and edit as a helper", [
    "Sign in as <b>Student 2</b> > <b>Profile</b> > <b>Team</b>: there is now an <b>Events</b> button. Tap it.",
    "Tap the pencil on an event, change the location, <b>Save changes</b>. Check: there is <b>no Cancel event</b> "
    "button.",
    "Tap <b>New event</b>, fill in " + k("Helper Event") + " in 5 days, publish.",
    "Sign in as <b>Test Student</b> > <b>Dashboard</b>."],
    "the edit is saved. <b>Helper Event</b> is published under <b>Test Student's</b> name (look at <i>Hosted by</i> "
    "on the event page) and appears on Test Student's dashboard, where only Test Student can cancel or delete it.")
s += test("Warning before publishing the same event twice", [
    "As <b>Student 2</b> > Team > <b>Events</b> > <b>New event</b>: use the title " + k("Helper Event") + " again "
    "and the <b>same day</b>. Tap <b>Publish Event</b>.",
    "Read the dialog and tap <b>Cancel</b>."],
    "a dialog <b>This event may already exist</b> names the existing event and its date and offers <b>Publish "
    "anyway</b>. After Cancel nothing was published.")
s += test("Two people editing the same event (needs two devices)", [
    "Device A: <b>Test Student</b> > Dashboard > pencil on Helper Event. Device B: <b>Student 2</b> > Team > Events "
    "> pencil on Helper Event.",
    "Wait up to 15 seconds and look at the top of both forms.",
    "On device A change the title to " + k("Helper Event A") + " and tap <b>Save changes</b>.",
    "On device B change the description and tap <b>Save changes</b>."],
    "a yellow bar on both: <i>... also has this event open for editing right now.</i> Device A saves normally. "
    "Device B gets <b>Someone changed this event</b>: its changes are <b>not</b> saved and the title from device A "
    "stays. After closing and reopening, device B can edit again.")
s += test("Remove a helper, and leaving", [
    "As <b>Test Student</b> > Team: tap the red icon on Student 2 > <b>Remove</b>.",
    "Sign in as <b>Student 2</b> > Profile > Team.",
    "(Optional) Invite Student 2 again, accept, then as Student 2 tap <b>Leave team</b>."],
    "<i>Removed from the team.</i> Student 2's team list is empty and the scan and events buttons are gone at once. "
    "Leaving works the same from the helper's side.")
s += test("University teams stay inside the university", [
    "Sign in as <b>HAW Student</b> (university organizer) > Profile > Team.",
    "Invite " + k("whp2718+student2@gmail.com") + " (a Gmail account). Look at the list.",
    "Invite " + k("who649@haw-hamburg.de") + " (the Admin, a HAW address). Look at the list."],
    "both times the same message, but only the <b>HAW</b> address appears in the list. A university organizer's "
    "team can only have people from the same university.",
    after=callout("NOTE", "A suspended helper cannot scan or edit, and a suspended organizer pauses the whole team: "
                  "the helper's card then says <i>This team is paused at the moment</i>. You can try this with the "
                  "Suspend button from Part 8."))
s.append(PageBreak())

# ------------------------------------------------------------------ part 10
s.append(P("Part 10 - The yearly check of university emails", H1))
s.append(P("Once a year every university account is asked to prove that its address still works, by typing in a code "
           "sent to it. Whoever does not do it within 30 days keeps the account but loses the university (and an "
           "organizer becomes a normal student). Nobody is due for a year, so for this part <b>ask Claude first</b>:"))
s += callout("NOTE", "Tell Claude: <i>\"Make HAW Student due for the yearly check.\"</i> Claude sets the date back. "
             "Your friend must be reachable, because the code goes to his inbox.")
s += test("The reminder", [
    "After Claude confirms, sign in as <b>HAW Student</b> (close and reopen the app if you were signed in).",
    "Look at the top of the app. Open <b>Profile</b> and look at the university row."],
    "a <b>blue bar</b>: <i>Yearly check: please confirm that your university email still works.</i> with a "
    "<b>Confirm</b> button. The university row says <i>Yearly check due. Tap to confirm your email.</i>")
s += test("Confirm with the code", [
    "Tap <b>Confirm</b> in the blue bar. The dialog names the HAW address. Tap <b>Send code</b>.",
    "First type a wrong code, e.g. " + k("000000") + ", and tap <b>Confirm</b>.",
    "Ask your friend for the code from the email <b>Your UniHub code</b>, type it and tap <b>Confirm</b>."],
    "the wrong code says <i>That code is wrong or has expired.</i> The right one: <i>Thank you. Your university "
    "email is confirmed.</i> The blue bar disappears and the university row has its green tick again.",
    after=callout("WARNING", "If the email contains a <b>link</b> instead of a code, the <b>Magic Link</b> email "
                  "template in the Supabase dashboard was not changed yet. Tell Claude."))
s += test("Missing the check (ask Claude to fast-forward)", [
    "Tell Claude: <i>\"Let HAW Student miss the yearly check.\"</i> Wait for the confirmation.",
    "Sign in as <b>HAW Student</b>. Look at the bottom bar, the bell, <b>Home</b> and the university row in <b>Profile</b>.",
    "Tap the university row > <b>Send code</b> > type the code from your friend > <b>Confirm</b>."],
    "before confirming: the organizer tabs are gone (a normal member again), the bell says <b>University access "
    "paused</b>, HAW Only Event is not in the feed, and the row says <i>Not confirmed this year. Tap to confirm your "
    "university email.</i> After confirming: the university is back and campus events show again. The organizer "
    "role does <b>not</b> come back by itself.")
s += test("Switch the yearly check off for a permanent address", [
    "As <b>Admin</b> > <b>Users</b>: give HAW Student the role <b>University organizer</b> again.",
    "Gear icon on HAW Student > <b>Switch yearly email check off</b>.",
    "Look at the line under the name. Then open the gear menu on <b>Student 2</b>.",
    "On HAW Student: <b>Switch yearly email check on</b> again."],
    "the line shows <b>No yearly email check</b>. Student 2 (not a university organizer) has no such menu item. "
    "After switching it on, the label is gone.")
s.append(PageBreak())

# ------------------------------------------------------------------ part 10
s.append(P("Part 11 - Profile, looks, the website on a PC, deleting an account", H1))
s += test("The new profile page", [
    "<b>Profile</b>: at the top is your name, email and role, like a member pass. Below, the settings are in "
    "groups (<b>Account</b>, <b>Notifications</b>, <b>Preferences</b>, <b>Privacy &amp; data</b>).",
    "<b>Edit name</b>, change it, <b>Save</b>.",
    "Try the name " + k("Admin") + " or " + k("UniHub Support") + " and save.",
    "<b>Change password</b> (then change it back or write it down).",
    "<b>Language</b> > <b>Deutsch</b>. Look around, then switch back to <b>English</b>. Close and reopen the app."],
    "<i>Saved.</i> for a normal name; the official-sounding names are refused: <i>This name cannot be used. Please "
    "choose another one.</i> The app turns German and back; the language is kept after reopening.")
s += test("Light and dark", [
    "<b>Profile</b> > <b>Theme Mode</b>: switch between <b>Light</b>, <b>Dark</b> and <b>System</b>.",
    "In dark mode open Home, My Tickets, an event page and the Dashboard.",
    "Check that there is <b>no wallpaper setting</b> any more."],
    "navy and white in light mode, dark with readable text in dark mode. Nothing overlaps.")
s += test("The website on a PC (needs a computer)", [
    "On the PC open PowerShell, type " + k("cd D:\\UniHub_v0.2") + " then " + k("flutter run -d chrome") +
    " and wait for the browser.",
    "Sign in as Test Student and make the window wide.",
    "Look at <b>Home</b>, an event page and <b>Profile</b>. Then drag the window narrow like a phone."],
    "wide: a navy menu on the left with written labels, events <b>two per row</b>, and a right column with "
    "<b>Your next ticket</b> and <b>Saved</b>. The event page and the profile use two columns and never stretch "
    "across the whole screen. Narrow: it looks like the phone app.")
s += test("Delete your own account (Throwaway)", [
    "Create " + k("whp2718+gone3@gmail.com") + ". Save one event with the heart.",
    "<b>Profile</b> > scroll to the bottom > <b>Delete account</b>. Type " + k("DELETE") + " > <b>Delete forever</b>.",
    "Try to sign in with that email."],
    "you are signed out; signing in says <i>Wrong email or password</i>. (An account that still owns events gets a "
    "message to ask an admin instead, <b>before</b> anything is deleted.)")
s.append(PageBreak())

# ------------------------------------------------------------------ part 11
s.append(P("Part 12 - If something goes wrong", H1))
s.append(P("Find what you see in the left column. If it isn't there, send me: the test number, what you tapped and a "
           "screenshot."))
s.append(Spacer(1, 4))
s.append(table([
    ["What you see", "What to do"],
    ["Phone says <i>App not installed</i>", "Uninstall the old UniHub (long-press the icon > Uninstall), then install again."],
    ["Phone blocks the install", "Tap <b>Install anyway</b> and allow installs from the Files app."],
    ["No code email arrives", "Wait 2 minutes and check spam. You can ask for a new code once a minute. For the HAW "
     "address the email is in your friend's inbox."],
    ["<i>That code is wrong or has expired</i>", "Use the newest email only. Ask for a new code."],
    ["The yearly-check email has a link, no code", "The Magic Link template in Supabase still has the old text. Tell Claude."],
    ["<i>This email address can't be used to sign up</i>", "An admin blocked it. Unblock it in Admin > Users > Blocked addresses."],
    ["A yellow bar: <i>Your account is suspended</i>", "An admin suspended this account. As Admin: Users > gear icon > <b>Reinstate</b>."],
    ["<i>This event is not available to you</i>", "It is a campus event of another university, or its organizer is suspended."],
    ["University organizer is missing in the role menu", "That account has no university email. Only Commercial planner is possible."],
    ["<b>University accounts only</b> instead of Register", "That account has no university email. Use Admin or HAW Student to register."],
    ["A ticket has no QR code", "The event has no QR check-in (open entry). That is intended."],
    ["<i>Someone changed this event</i> when saving", "A teammate saved first. Close the page, open the event again and redo your change."],
    ["The Team buttons are grey / <i>team is paused</i>", "The organizer or you are suspended, or you are no longer at the organizer's university."],
    ["An invited person does not appear in My team", "The address has no account, or (university organizer) it is not from your university."],
    ["A change doesn't show", "Wait up to half a minute, or pull the list down. If it still doesn't show, note the screen."],
    ["Events don't load / <i>Could not load</i>", "Check the phone's internet, pull down to refresh, or close and reopen the app."],
    ["No push messages", "Profile > Notifications card. If it says blocked: phone Settings > Apps > UniHub > "
     "Notifications > on. Remember: push goes only to the account signed in on this phone."],
    ["Scanner shows a black screen", "Camera permission: phone Settings > Apps > UniHub > Permissions > Camera > Allow."],
    ["Scanner says <i>not allowed to scan</i>", "Only the organizer of that event can check people in (and not while suspended)."],
    ["<b>Leave Review</b> is missing or refused", "The event hasn't started yet, it needs a QR check-in first, or you already reviewed it."],
    ["<i>That action is not allowed or failed</i> (admin)", "Check the internet and try again. Admins can't be suspended "
     "or removed until their role is changed to a normal user."],
    ["<i>You still own events</i> when deleting your account", "Use a fresh Throwaway account, or ask an admin to remove the account."],
    ["Admin tab is missing", "Only admin accounts have it, in the organizer view: tap your name > <b>Switch to organizer view</b>."],
    ["Poster upload refused", "Use a JPG, PNG or WebP photo under 5 MB."],
], [58, 112]))
s.append(Spacer(1, 8))
s.append(P("Words explained", H2))
s.append(table([
    ["Word", "Meaning"],
    ["Organizer", "An approved account that may publish events and check guests in. University organizers need a university email."],
    ["Commercial planner", "An approved account without a university that publishes public events."],
    ["Campus event", "An 'official university event': only accounts of that university can see it."],
    ["Waitlist", "A queue for full events. People move up automatically when someone cancels."],
    ["Push message", "A notification that pops up on the phone even when the app is closed."],
    ["Suspended", "Paused by an admin while reports are checked. Nothing is deleted and it can be undone."],
    ["Case file", "The record of a suspension, reinstatement or removal, with the reports as proof. Kept for 12 months."],
    ["Team", "People an organizer invited to help. Each may scan tickets, create and edit events, or both."],
    ["Open entry", "An event without QR check-in: tickets have no code and nothing is scanned."],
    ["Yearly check", "Once a year a university account proves its address still works by typing in a code."],
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

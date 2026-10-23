// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UNIHUB';

  @override
  String get studentRole => 'Student';

  @override
  String get plannerRole => 'Planner';

  @override
  String get toggleRole => 'Switch Role';

  @override
  String get tenantName => 'University Events Portal';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTickets => 'My Tickets';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabCreateEvent => 'Create Event';

  @override
  String get tabScanner => 'Scanner';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get studentHomeTitle => 'Upcoming Campus Events';

  @override
  String get studentTicketsTitle => 'My Tickets';

  @override
  String get studentProfileTitle => 'Profile Settings';

  @override
  String get plannerDashboardTitle => 'Event Analytics';

  @override
  String get plannerCreateEventTitle => 'Create New Event';

  @override
  String get plannerScannerTitle => 'QR Ticket Scanner';

  @override
  String get mockEventTitle => 'Spring Campus Concert';

  @override
  String get mockEventDate => 'June 24, 2026';

  @override
  String get mockEventLocation => 'Main Hall';

  @override
  String get mockEventDescription =>
      'Join us for an evening of live music, food stalls, and community.';

  @override
  String get tabCampusHub => 'Campus Hub';

  @override
  String get tabPublicEvents => 'Public Events';

  @override
  String get fieldOfficial => 'Is University Official';

  @override
  String get fieldRequireQr => 'Require QR Code Check-in';

  @override
  String get fieldAllowReviews => 'Allow User Reviews';

  @override
  String get headerLivePreview => 'Live Preview';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryMusic => 'Music';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryArts => 'Arts';

  @override
  String get officialBadge => 'OFFICIAL';

  @override
  String get publicBadge => 'PUBLIC';

  @override
  String get formFieldTitle => 'Event Title';

  @override
  String get formFieldLocation => 'Location / Room';

  @override
  String get formFieldCategory => 'Category';

  @override
  String get formFieldDescription => 'Description';

  @override
  String get formFieldCapacity => 'Participant Capacity';

  @override
  String get buttonPublish => 'Publish Event';

  @override
  String get buttonLeaveReview => 'Leave Review';

  @override
  String get buttonSubmitReview => 'Submit Review';

  @override
  String get reviewTitle => 'Post-Event Review';

  @override
  String get reviewRating => 'Rating';

  @override
  String get reviewComment => 'Comments';

  @override
  String get reviewCommentHint => 'Share your experience about the event...';

  @override
  String get reviewAttendanceClaim => 'Did you actually attend this event?';

  @override
  String get reviewVerifiedLabel => 'Verified Review';

  @override
  String get reviewUnverifiedLabel => 'Unverified Review';

  @override
  String get reviewWarningDisclaimer =>
      'Unverified data: For internal organizer tracking only.';

  @override
  String get reviewSuccessMsg => 'Review submitted successfully!';

  @override
  String get reviewRestrictedMsg =>
      'Only checked-in attendees can review this event.';

  @override
  String get dashboardPublicRatings => 'Public Ratings';

  @override
  String get dashboardPrivateFeedback => 'Private Internal Feedback';

  @override
  String get dashboardTotalRsvps => 'Total RSVPs';

  @override
  String get dashboardTotalCheckins => 'Total Check-ins';

  @override
  String get dashboardAttendanceRate => 'Attendance Rate';

  @override
  String get prefThemeMode => 'Theme Mode';

  @override
  String get prefWallpaper => 'Wallpaper Overlay';

  @override
  String get wallpaperNone => 'None';

  @override
  String get wallpaperGrid => 'Grid';

  @override
  String get wallpaperSunset => 'Sunset';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get authWelcome => 'Welcome to UNIHUB';

  @override
  String get authTagline => 'Your campus events, in one place.';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authDisplayName => 'Your name';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccount => 'New here? Create an account';

  @override
  String get authHaveAccount => 'Already have an account? Sign in';

  @override
  String authUniDetected(String university) {
    return 'University account detected: $university';
  }

  @override
  String get authPublicAccount =>
      'No university email detected. You will see public events only.';

  @override
  String get authVerifyTitle => 'Check your email';

  @override
  String authVerifyBody(String email) {
    return 'We sent a code to $email. Enter it below.';
  }

  @override
  String get authCode => 'Code from your email';

  @override
  String get authVerify => 'Verify';

  @override
  String get authResend => 'Resend code';

  @override
  String get authResent => 'A new code was sent.';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetBody => 'Enter your email and we will send you a code.';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authResetSubmit => 'Set new password';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authErrInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrPasswordShort => 'Password must be at least 8 characters.';

  @override
  String get authErrNameRequired => 'Please enter your name.';

  @override
  String get authErrCodeRequired => 'Enter the code from your email.';

  @override
  String get authErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get authErrBadCredentials => 'Wrong email or password.';

  @override
  String get authErrEmailNotConfirmed => 'Please confirm your email first.';

  @override
  String get authErrCodeInvalid => 'That code is wrong or has expired.';

  @override
  String get authErrNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authProfileLoadFailed => 'Could not load your profile.';

  @override
  String get authRetry => 'Try again';

  @override
  String get eventsLoadFailed => 'Could not load events.';

  @override
  String get eventPublishNotAllowed =>
      'Your account is not approved to publish events yet.';

  @override
  String get eventPublishFailed =>
      'The event could not be published. Please check the details and try again.';

  @override
  String registerSuccess(String title) {
    return 'Successfully registered for $title!';
  }

  @override
  String registerWaitlisted(String title) {
    return '$title is full. You are on the waitlist.';
  }

  @override
  String get registerEventOver => 'This event has already ended.';

  @override
  String get registerEventUnavailable => 'This event is not available to you.';

  @override
  String get registerPaidNotSupported => 'Paid events are not supported yet.';

  @override
  String get registerFailed => 'Registration failed. Please try again.';

  @override
  String get ctaWaitlisted => 'Waitlisted';

  @override
  String get ticketsWaitlistBadge => 'ON WAITLIST';

  @override
  String get ticketsWaitlistNote =>
      'You will get a ticket automatically if a spot opens up.';

  @override
  String get ticketCancel => 'Cancel registration';

  @override
  String get ticketCancelConfirmTitle => 'Cancel registration?';

  @override
  String get ticketCancelConfirmBody =>
      'Your ticket will stop working and your spot goes to the next person.';

  @override
  String get ticketCancelYes => 'Yes, cancel';

  @override
  String get ticketCancelNo => 'Keep it';

  @override
  String get ticketCancelled => 'Registration cancelled.';

  @override
  String get ticketCancelFailed => 'Could not cancel. Please try again.';

  @override
  String get ticketCancelCheckedIn => 'You are already checked in.';

  @override
  String get ticketsRefresh => 'Refresh';

  @override
  String get reviewErrCheckInRequired =>
      'You can review this event after you have been checked in.';

  @override
  String get reviewErrNotStarted =>
      'You can review an event after it has started.';

  @override
  String get reviewErrAlready => 'You have already reviewed this event.';

  @override
  String get reviewErrNotAllowed => 'Reviews are not enabled for this event.';

  @override
  String get reviewErrGeneric =>
      'Your review could not be sent. Please try again.';

  @override
  String get reviewAlreadySubmitted => 'Review submitted';

  @override
  String get reviewOpensAtStart => 'Reviews open when the event starts.';

  @override
  String get detailsNoRatings => 'No ratings yet';

  @override
  String get detailsEventRating => 'Event rating';

  @override
  String detailsReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verified reviews',
      one: '1 verified review',
    );
    return '$_temp0';
  }

  @override
  String get dashboardNoEventsYet =>
      'No events yet. Create one to see your numbers here.';

  @override
  String get dashboardLoadFailed => 'Could not load the dashboard.';

  @override
  String get scanLogEmpty => 'No scans yet.';

  @override
  String scanLogGranted(String ticket) {
    return '$ticket checked in';
  }

  @override
  String scanLogAlreadyUsed(String ticket) {
    return '$ticket scanned again (already used)';
  }

  @override
  String get scanLogInvalid => 'Invalid ticket code';

  @override
  String scanLogWrongEvent(String ticket) {
    return '$ticket belongs to another event';
  }

  @override
  String scanLogCancelled(String ticket) {
    return '$ticket was cancelled';
  }

  @override
  String dashboardSeatsLine(int registered, int capacity, int checkedIn) {
    return '$registered of $capacity seats, $checkedIn checked in';
  }

  @override
  String dashboardUnlimitedLine(int registered, int checkedIn) {
    return '$registered registered (no limit), $checkedIn checked in';
  }

  @override
  String dashboardWaitlistCount(int count) {
    return '$count on waitlist';
  }

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n d ago';
  }
}

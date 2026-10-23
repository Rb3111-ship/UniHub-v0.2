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

  @override
  String get authBrowseAsGuest => 'Browse events without an account';

  @override
  String get guestBanner => 'Browsing as a guest';

  @override
  String get guestSignInTitle => 'Sign in to continue';

  @override
  String get guestSignInBody =>
      'Create a free account or sign in to register for events.';

  @override
  String get guestNotNow => 'Not now';

  @override
  String get profileEditName => 'Edit name';

  @override
  String get profileNameLabel => 'Your name';

  @override
  String get profileSave => 'Save';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileSaved => 'Saved.';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profilePasswordChanged => 'Password changed.';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteTitle => 'Delete your account?';

  @override
  String get profileDeleteBody =>
      'This permanently deletes your account, registrations, tickets and reviews. It cannot be undone.';

  @override
  String get profileDeleteTypeHint => 'Type DELETE to confirm';

  @override
  String get profileDeleteConfirm => 'Delete forever';

  @override
  String get profileDeleteHasEvents =>
      'You still own events. Please ask an admin for help before deleting your account.';

  @override
  String get profileDeleteLastAdmin =>
      'You are the only platform admin. Make someone else an admin first.';

  @override
  String get profileDeleteFailed =>
      'The account could not be deleted. Please try again.';

  @override
  String get profileSwitchToStudent => 'Switch to student view';

  @override
  String get profileSwitchToOrganizer => 'Switch to organizer view';

  @override
  String get organizerBecomeTitle => 'Become an organizer';

  @override
  String get organizerBecomeBody =>
      'Publish events for your university or as a business. An admin reviews every request.';

  @override
  String get organizerRoleUniversity => 'University organizer';

  @override
  String get organizerRoleCommercial => 'Commercial / public events';

  @override
  String get organizerOrgName => 'Organization or club name';

  @override
  String get organizerMessage => 'Why do you need access? (optional)';

  @override
  String get organizerSubmit => 'Send request';

  @override
  String get organizerRequestSent => 'Request sent. An admin will review it.';

  @override
  String get organizerStatusPending => 'Your request is waiting for review.';

  @override
  String get organizerStatusApproved =>
      'Your request was approved. Tap \'Check status\' to unlock organizer tools.';

  @override
  String get organizerStatusRejected => 'Your last request was not approved.';

  @override
  String get organizerCheckStatus => 'Check status';

  @override
  String get organizerErrNoUniversity =>
      'You need a university email address to become a university organizer.';

  @override
  String get organizerErrPending => 'You already have a request waiting.';

  @override
  String get organizerErrGeneric =>
      'The request could not be sent. Please check the name and try again.';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get adminRequests => 'Requests';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminNoRequests => 'No requests.';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminNoteHint => 'Note for the applicant (optional)';

  @override
  String get adminRequestApproved => 'Approved.';

  @override
  String get adminRequestRejected => 'Rejected.';

  @override
  String get adminActionFailed => 'That action is not allowed or failed.';

  @override
  String get adminSearchHint => 'Search name or email';

  @override
  String get adminChangeRole => 'Change role';

  @override
  String get adminLoadFailed => 'Could not load the admin data.';

  @override
  String get roleStudent => 'Student';

  @override
  String get roleOrganizer => 'University organizer';

  @override
  String get roleCommercial => 'Commercial planner';

  @override
  String get roleTenantAdmin => 'University admin';

  @override
  String get rolePlatformAdmin => 'Platform admin';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get eventEditTitle => 'Edit event';

  @override
  String get eventSaveChanges => 'Save changes';

  @override
  String get eventSaved => 'Event updated.';

  @override
  String get eventCancelEvent => 'Cancel event';

  @override
  String get eventCancelConfirmTitle => 'Cancel this event?';

  @override
  String get eventCancelConfirmBody =>
      'Everyone with a ticket will see it as cancelled. This cannot be undone.';

  @override
  String get eventCancelYes => 'Yes, cancel event';

  @override
  String get eventCancelledMsg => 'Event cancelled.';

  @override
  String get eventCancelFailed => 'The event could not be cancelled.';

  @override
  String get eventAddImage => 'Add poster image';

  @override
  String get eventChangeImage => 'Change image';

  @override
  String get eventImageTooBig => 'The image is too large (maximum 5 MB).';

  @override
  String get eventImageBadType => 'Please use a JPG, PNG or WebP image.';

  @override
  String get eventImageUploadFailed =>
      'The image could not be uploaded. Please try again.';

  @override
  String get eventStatusCancelled => 'CANCELLED';

  @override
  String get ticketEventCancelled =>
      'This event was cancelled. Your ticket is no longer valid.';

  @override
  String get dashboardEdit => 'Edit';
}

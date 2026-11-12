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
  String get dashboardTotalRsvps => 'Total registrations';

  @override
  String get dashboardTotalCheckins => 'Total Check-ins';

  @override
  String get dashboardAttendanceRate => 'Attendance Rate';

  @override
  String get prefThemeMode => 'Theme Mode';

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

  @override
  String get prefSection => 'Preferences';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get universityLabel => 'University';

  @override
  String get universityFromEmail =>
      'Set automatically from your verified university email.';

  @override
  String get universityNone =>
      'No university - public account. Sign up with your university email to join one.';

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get privacySubtitle => 'What we store, who can see it, and your copy';

  @override
  String get privacyWhatTitle => 'What UniHub stores about you';

  @override
  String get privacyWhatBody =>
      'Your email address and name, your university (taken from your email domain), your language, the events you registered for with their tickets and check-ins, the reviews you wrote and any organizer requests. Organizers and admins can also add a profile photo.';

  @override
  String get privacyWhoTitle => 'Who can see it';

  @override
  String get privacyWhoBody =>
      'Only you can see your registrations and tickets. Organizers see the names of people registered for their own events and the feedback on them. Admins see the account list of their university. Verified reviews are public, without your email. Your password is never visible to anyone.';

  @override
  String get privacyLocalTitle => 'On this device only';

  @override
  String get privacyLocalBody =>
      'Your theme choice is stored on this device, not in your account.';

  @override
  String get privacyExport => 'Copy my data';

  @override
  String get privacyExportDone =>
      'Your data was copied to the clipboard (JSON). Paste it into a note or email to keep it.';

  @override
  String get privacyExportFailed =>
      'Your data could not be loaded. Please try again.';

  @override
  String get privacyDeleteHint =>
      'To remove everything for good, use Delete account at the bottom of your profile.';

  @override
  String get avatarChange => 'Change photo';

  @override
  String get avatarRemove => 'Remove photo';

  @override
  String get avatarUpdated => 'Photo updated.';

  @override
  String get avatarRemoved => 'Photo removed.';

  @override
  String get avatarFailed =>
      'The photo could not be saved. Use a JPG, PNG or WebP image under 2 MB.';

  @override
  String get passwordCurrent => 'Current password';

  @override
  String get passwordRepeat => 'Repeat new password';

  @override
  String get passwordMismatch => 'The new passwords do not match.';

  @override
  String get passwordWrongCurrent => 'Your current password is not correct.';

  @override
  String get passwordSameAsOld =>
      'The new password must be different from the current one.';

  @override
  String get guestSignInButton => 'Sign in / Sign up';

  @override
  String get guestOpenTitle => 'Sign in to see this event';

  @override
  String get guestOpenBody =>
      'Create a free account or sign in to see event details and register.';

  @override
  String get guestFeedTitle => 'Public events';

  @override
  String get authBackToEvents => 'Back to events';

  @override
  String get eventsEmptyCategory => 'No events found in this category.';

  @override
  String get detailsDateTime => 'Date & time';

  @override
  String get detailsLocation => 'Location';

  @override
  String get detailsAbout => 'About this event';

  @override
  String get detailsHostedBy => 'Hosted by';

  @override
  String get detailsGallery => 'Gallery';

  @override
  String badgeOfficial(String university) {
    return '$university OFFICIAL';
  }

  @override
  String get badgePublic => 'PUBLIC EVENT';

  @override
  String get detailsFree => 'FREE ADMISSION';

  @override
  String get detailsQrRequired => 'QR code ticket required at the door';

  @override
  String get detailsOpenAdmission =>
      'Open admission - register so the organizer can plan';

  @override
  String get detailsSeeTickets => 'Your entry QR code is in My Tickets';

  @override
  String get detailsTicketReserved => 'TICKET RESERVED';

  @override
  String get detailsWaitlistedLabel => 'WAITLISTED';

  @override
  String get detailsWaitlistBody =>
      'You get a ticket automatically if a seat frees up';

  @override
  String get detailsCancelledBody =>
      'This event was cancelled by the organizer.';

  @override
  String get detailsEndedBody => 'This event has already ended.';

  @override
  String get ctaRegister => 'Register';

  @override
  String get ctaRegistered => 'Registered';

  @override
  String get ctaUnavailable => 'Not available';

  @override
  String detailsCapacity(int count) {
    return '$count places';
  }

  @override
  String get detailsUnlimited => 'No limit on places';

  @override
  String get ticketsEmptyTitle => 'No tickets yet';

  @override
  String get ticketsEmptyBody =>
      'Register for an event on the Home tab and your entry QR code appears here.';

  @override
  String get ticketCheckedInBadge => 'CHECKED IN';

  @override
  String get ticketConfirmedBadge => 'CONFIRMED';

  @override
  String get ticketEndedBadge => 'ENDED';

  @override
  String get ticketLabelDate => 'DATE';

  @override
  String get ticketLabelLocation => 'LOCATION';

  @override
  String get ticketLabelEntry => 'ENTRY';

  @override
  String get ticketEntryQr => 'QR check-in';

  @override
  String get ticketEntryOpen => 'Open entry';

  @override
  String get ticketLabelId => 'TICKET';

  @override
  String get ticketScannedOk => 'Ticket scanned - enjoy the event!';

  @override
  String get ticketShowAtEntrance => 'Show this QR code at the entrance';

  @override
  String get scanChooseEventFirst =>
      'Choose the event you are scanning for first.';

  @override
  String get scanNotUnihub => 'This is not a UniHub ticket.';

  @override
  String scanGranted(String name) {
    return 'Welcome, $name! Checked in.';
  }

  @override
  String scanAlreadyUsed(String name) {
    return '$name was already checked in.';
  }

  @override
  String get scanWrongEvent => 'This ticket is for a different event.';

  @override
  String get scanCancelled => 'This ticket was cancelled.';

  @override
  String get scanInvalid => 'Invalid ticket.';

  @override
  String get scanNotAllowed =>
      'You are not allowed to scan tickets for this event.';

  @override
  String get scanOffline =>
      'Could not reach the server. Check your connection and scan again.';

  @override
  String get scanGuestFallback => 'guest';

  @override
  String get scanAccessGranted => 'Access granted';

  @override
  String get scanAccessDenied => 'Access denied';

  @override
  String get scanClose => 'Close';

  @override
  String get scanEnterCode => 'Enter ticket code';

  @override
  String get scanEnterCodeHint => 'Paste the code from the ticket';

  @override
  String get scanCheckIn => 'Check in';

  @override
  String get scanNoEvents =>
      'You have no events to scan for. Create one to start checking in guests.';

  @override
  String get scanEventsFailed => 'Your events could not be loaded.';

  @override
  String get scanPointCamera => 'Point the camera at a ticket QR code';

  @override
  String get scanPointCameraDemo =>
      'Point the camera at a ticket QR code or tap \'Demo scan\'';

  @override
  String get scanDemoButton => 'Demo scan';

  @override
  String get scanProcessing => 'Checking ticket...';

  @override
  String get scanTorch => 'Flashlight';

  @override
  String get scanManual => 'Enter code manually';

  @override
  String get formHeader => 'Event details';

  @override
  String get formTitleHint => 'e.g. Spring Hackathon 2026';

  @override
  String get formTitleError => 'Please enter a title (3 to 140 characters).';

  @override
  String get formCategories => 'Categories (up to 3)';

  @override
  String get formCategoriesMax => 'You can select up to 3 categories.';

  @override
  String get categoryAcademic => 'Academic';

  @override
  String get categoryOther => 'Other';

  @override
  String get formLocationHint => 'e.g. Main Hall, Building B';

  @override
  String get formLocationError => 'Please enter a location.';

  @override
  String get formStarts => 'Starts';

  @override
  String get formEnds => 'Ends';

  @override
  String get formChange => 'Change';

  @override
  String get formEndBeforeStart => 'The event must end after it starts.';

  @override
  String get formStartInPast =>
      'The start time is in the past. Please pick a later time.';

  @override
  String get adminRemoveReview => 'Remove review';

  @override
  String get adminRemoveReviewConfirm =>
      'This review will be deleted for good. Its stars no longer count.';

  @override
  String get adminReviewRemoved => 'Review removed.';

  @override
  String get profileNameNotAllowed =>
      'This name cannot be used. Please choose another one.';

  @override
  String get homeNextTicket => 'Your next ticket';

  @override
  String get homeNoTicketYet =>
      'No ticket yet. Register for an event and it shows up here.';

  @override
  String get homeSavedTitle => 'Saved';

  @override
  String get homeSavedNone => 'Tap the heart on an event to keep it here.';

  @override
  String get ticketAdmitOne => 'Admit one';

  @override
  String get profileRoleLabel => 'Role';

  @override
  String formCapacityBelowRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are',
      one: '1 person is',
    );
    return '$_temp0 already registered. The limit cannot be lower than that.';
  }

  @override
  String get formCapacityBelowRegisteredUnknown =>
      'The limit cannot be lower than the number of people already registered.';

  @override
  String formCapacityError(int max) {
    return 'Enter a number from 1 to $max.';
  }

  @override
  String get formNoLimit => 'No attendee limit';

  @override
  String get formOfficialTitle => 'Official university event';

  @override
  String formOfficialBody(String university) {
    return 'Only members of $university can see it.';
  }

  @override
  String get formPublicTitle => 'Public event';

  @override
  String get formPublicBody => 'Everyone can see it, also without an account.';

  @override
  String get formDescriptionHint => 'Schedule, speakers, rules ...';

  @override
  String get eventPublished => 'Event published.';

  @override
  String get previewTitlePlaceholder => 'Your event title';

  @override
  String get previewLocationPlaceholder => 'Location';

  @override
  String get previewDescPlaceholder => 'Your description appears here.';

  @override
  String get previewReviewsOn => 'Reviews on';

  @override
  String get reviewErrCommentRequired => 'Please write a comment.';

  @override
  String get dashboardAttendanceByEvent => 'Attendance by event';

  @override
  String get dashboardRecentScans => 'Recent scans';

  @override
  String get dashboardActiveEvents => 'Active events';

  @override
  String get dashboardNoPublicRatings => 'No public ratings yet.';

  @override
  String get dashboardNoPrivateFeedback => 'No private feedback yet.';

  @override
  String get dashboardClaimedAttendance => 'Says they attended';

  @override
  String get formCustomCategoryLabel => 'Your own category (optional)';

  @override
  String get formCustomCategoryHint => 'e.g. Yoga, Gaming, Careers';

  @override
  String get formCustomCategoryError => 'Use 2 to 30 letters or numbers.';

  @override
  String get posterShowFull => 'Show the whole poster';

  @override
  String get posterClose => 'Close';

  @override
  String get linkCopied => 'No app found to open this, so it was copied.';

  @override
  String get detailsContactTitle => 'Contact & links';

  @override
  String get contactWebsite => 'Website';

  @override
  String get contactEmail => 'Email';

  @override
  String get contactPhone => 'Phone';

  @override
  String get formContactSection => 'Contact & links (optional)';

  @override
  String get formContactHint =>
      'Students see these as tappable links on the event page.';

  @override
  String get formWebsiteError => 'Enter a web address like www.example.org.';

  @override
  String get formPhoneError =>
      'Enter a phone number (digits, spaces and + - / ( ) only).';

  @override
  String get otherCategoriesTitle => 'More categories';

  @override
  String get otherCategoriesAll => 'All other events';

  @override
  String get otherCategoriesEmpty => 'No other categories yet.';

  @override
  String get searchHint => 'Search events, categories, organizers';

  @override
  String get searchOpen => 'Search';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchNoResults => 'No events match your search.';

  @override
  String byOrganizer(String name) {
    return 'by $name';
  }

  @override
  String get authConfirmFirst =>
      'Please confirm your email first. We sent you a new code.';

  @override
  String get authChangeEmail => 'Wrong email? Start again';

  @override
  String get registerOwnEvent =>
      'You organize this event, so you cannot register for it.';

  @override
  String get ownEventHeadline => 'YOUR EVENT';

  @override
  String get ownEventBody => 'Manage it in organizer view.';

  @override
  String get ctaOwnEvent => 'Your event';

  @override
  String get applyIntro =>
      'Tell us who you are. An admin checks every request and may call you before approving it.';

  @override
  String get applyTypeSection => 'What do you want to publish?';

  @override
  String get applyAboutSection => 'You and your organization';

  @override
  String get applyPosition => 'Your position';

  @override
  String get applyPositionHint => 'e.g. Chair of the film club, event manager';

  @override
  String get applyPositionRequired => 'Please enter your position.';

  @override
  String get applyWebsite => 'Website of the organization (optional)';

  @override
  String get applyContactSection => 'Phone number';

  @override
  String get applyContactHint =>
      'Only admins see it. We use it to confirm the request is really from you.';

  @override
  String get applyPhone => 'Phone number';

  @override
  String get applyPhoneRequired => 'Please enter a phone number.';

  @override
  String get applyDocsSection => 'Proof (optional, up to 3 files)';

  @override
  String get applyDocsHint =>
      'For example a letter from your university, a club registration or a reference. PDF, JPG or PNG, up to 5 MB each. Only admins can open them, and they are deleted after the decision.';

  @override
  String get applyDocAdd => 'Add document';

  @override
  String get applyDocRemove => 'Remove';

  @override
  String get applyDocTooBig => 'This file is larger than 5 MB.';

  @override
  String get applyDocWrongType => 'Please choose a PDF, JPG or PNG file.';

  @override
  String get applyDocFailed =>
      'The document could not be uploaded. Please try again.';

  @override
  String get applyMessageSection => 'Anything else?';

  @override
  String get applyConsent =>
      'An admin may call me and look at my documents to verify this request.';

  @override
  String get applyConsentRequired => 'Please confirm this to send the request.';

  @override
  String adminDocument(int number) {
    return 'Document $number';
  }

  @override
  String get adminDocFailed => 'The document could not be opened.';

  @override
  String get adminDocsDeleted => 'Documents were deleted after the decision.';

  @override
  String get adminNoVerificationDetails =>
      'Sent before phone numbers were required: ask for details by email.';

  @override
  String get favoriteAdd => 'Save event';

  @override
  String get favoriteRemove => 'Remove from saved';

  @override
  String get favoriteFailed => 'Could not save. Please try again.';

  @override
  String get favoriteGuestBody =>
      'Sign in to save events and find them again later.';

  @override
  String get savedShowOnly => 'Show saved events';

  @override
  String get savedShowAll => 'Show all events';

  @override
  String get savedEmpty =>
      'No saved events here yet. Tap the heart on an event to save it.';

  @override
  String get addToCalendar => 'Add to calendar';

  @override
  String get reportTitle => 'Report event';

  @override
  String get reportBody =>
      'Why should an admin check this event? Your name is not shown to the organizer.';

  @override
  String get reportReasonSpam => 'Spam or advertising';

  @override
  String get reportReasonInappropriate => 'Offensive or inappropriate';

  @override
  String get reportReasonMisleading => 'Wrong or misleading information';

  @override
  String get reportReasonScam => 'Scam or fake event';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportDetails => 'Details (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Thank you. An admin will look at it.';

  @override
  String get reportAlready => 'You already reported this event.';

  @override
  String get reportTooMany =>
      'You sent many reports today. Please try again tomorrow.';

  @override
  String get reportFailed => 'The report could not be sent. Please try again.';

  @override
  String get detailsModeratedBody => 'This event was removed by a moderator.';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminNoReports => 'No reports.';

  @override
  String get reportStatusOpen => 'Open';

  @override
  String get reportStatusDismissed => 'Dismissed';

  @override
  String get reportStatusRemoved => 'Event removed';

  @override
  String get adminDismissReport => 'Dismiss';

  @override
  String get adminRemoveEvent => 'Remove event';

  @override
  String get adminDismissReportBody =>
      'The event stays online. Only this report is closed.';

  @override
  String adminRemoveEventBody(String title) {
    return '\"$title\" will be cancelled for everyone and its tickets stop working. This cannot be undone.';
  }

  @override
  String get adminRemoveNoteHint => 'Reason shown on the event page (optional)';

  @override
  String get adminEventRemoved => 'Event removed.';

  @override
  String get adminReportDismissed => 'Report dismissed.';

  @override
  String adminReportCount(int count) {
    return '$count reports';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty =>
      'No notifications yet. We\'ll let you know when an event you registered for changes.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsView => 'View';

  @override
  String get notificationsEventGone => 'This event is no longer available.';

  @override
  String get notifEventCancelledTitle => 'Event cancelled';

  @override
  String notifEventCancelledBody(String title) {
    return '$title has been cancelled.';
  }

  @override
  String get notifEventChangedTitle => 'Event updated';

  @override
  String notifEventChangedBody(String title) {
    return '$title: the time or place has changed.';
  }

  @override
  String get notifWaitlistTitle => 'You got a spot!';

  @override
  String notifWaitlistBody(String title) {
    return 'You\'re now registered for $title. Your ticket is ready.';
  }

  @override
  String get notifReminderTitle => 'Reminder';

  @override
  String notifReminderBody(String title, String when) {
    return '$title starts $when.';
  }

  @override
  String get notifRequestApprovedTitle => 'Application approved';

  @override
  String get notifRequestApprovedBody =>
      'You can now publish events on UniHub.';

  @override
  String get notifRequestRejectedTitle => 'Application not approved';

  @override
  String get notifRequestRejectedBody => 'See your profile for details.';

  @override
  String get notifEventRemovedTitle => 'Event removed';

  @override
  String notifEventRemovedBody(String title) {
    return '$title was removed after a report.';
  }

  @override
  String get notifSettingsTitle => 'Notifications';

  @override
  String get notifRemindersLabel => 'Event reminders';

  @override
  String get notifRemindersHint =>
      'A reminder in the 24 hours before events you registered for';

  @override
  String get notifUpdatesLabel => 'Event updates';

  @override
  String get notifUpdatesHint =>
      'Cancellations, new times or places, and waitlist spots';

  @override
  String get notifAccountHint =>
      'Messages about your account and \"Are you still coming?\" questions are always sent, because your seat may depend on them.';

  @override
  String get notifPushOn => 'Push messages are on for this device.';

  @override
  String get notifPushBlocked =>
      'Notifications are blocked for UniHub. Allow them in your phone\'s settings to get push messages.';

  @override
  String get notifPushUnavailable =>
      'Push messages aren\'t available on this device yet. You\'ll still see everything in the notification list.';

  @override
  String get notifSaveFailed =>
      'Couldn\'t save the setting. Check your connection.';

  @override
  String get confirmTitle => 'Are you still coming?';

  @override
  String get confirmBody =>
      'Please let the organizer know. If you can\'t make it, free your seat so someone else can come.';

  @override
  String get confirmReleaseWarning =>
      'Seats that aren\'t confirmed 24 hours before the start may go to people on the waitlist.';

  @override
  String get confirmYes => 'Yes, I\'m coming';

  @override
  String get confirmNo => 'I can\'t come';

  @override
  String get confirmDone => 'Thanks! Your seat is confirmed.';

  @override
  String get confirmedBadge => 'Confirmed';

  @override
  String get confirmFreeTitle => 'Free your seat?';

  @override
  String confirmFreeBody(Object title) {
    return 'Your registration for $title will be cancelled and the seat goes to the next person waiting.';
  }

  @override
  String get confirmFreeAction => 'Free seat';

  @override
  String get confirmFreed => 'Seat freed. Thanks for letting us know!';

  @override
  String get confirmFailed => 'That didn\'t work. Please try again.';

  @override
  String get notifConfirmTitle => 'Still coming?';

  @override
  String notifConfirmBody(Object title) {
    return '$title: please confirm your seat or free it for someone else.';
  }

  @override
  String get notifSeatReleasedTitle => 'Seat released';

  @override
  String notifSeatReleasedBody(Object title) {
    return 'You didn\'t confirm your seat for $title, so it went to the waitlist.';
  }

  @override
  String get notifReviewPromptTitle => 'How was it?';

  @override
  String notifReviewPromptBody(Object title) {
    return '$title is over. Tap to leave a quick review.';
  }

  @override
  String get fieldReleaseUnconfirmed => 'Free unconfirmed seats';

  @override
  String get fieldReleaseUnconfirmedHint =>
      'About 3 days before, attendees are asked if they\'re still coming. 24 hours before the start, seats of people who didn\'t answer go to the waitlist (only if someone is waiting).';

  @override
  String get insightsTitle => 'Event statistics';

  @override
  String get insightsOpen => 'Statistics';

  @override
  String get insightsTapHint => 'Tap an event to see its statistics.';

  @override
  String get insightsOverviewTitle => 'Registered, confirmed and came';

  @override
  String get legendRegistered => 'Registered';

  @override
  String get legendConfirmed => 'Confirmed';

  @override
  String get legendCame => 'Came';

  @override
  String get insightsCameUnknown =>
      'Open events have no door scan, so \'came\' is only known for ticket events.';

  @override
  String get insightsRatingTrend => 'Average stars per event';

  @override
  String get insightsNoRatings => 'No ratings yet';

  @override
  String get insightsSignups => 'Sign-ups per day';

  @override
  String get insightsNoSignups => 'No sign-ups yet';

  @override
  String get insightsStars => 'Ratings';

  @override
  String insightsAverage(Object avg, Object count) {
    return '$avg average from $count ratings';
  }

  @override
  String insightsVerifiedNote(Object count) {
    return '$count verified by door scan';
  }

  @override
  String get insightsAttendance => 'Attendance';

  @override
  String get insightsConfirmation => 'Attendance check';

  @override
  String insightsConfirmationLine(
      Object asked, Object confirmed, Object declined, Object released) {
    return '$asked asked · $confirmed confirmed · $declined can\'t come · $released seats freed';
  }

  @override
  String get insightsNotAskedYet =>
      'Attendees are asked about 3 days before the event.';

  @override
  String get statNoShow => 'No-show';

  @override
  String get statWaitlist => 'Waitlist';

  @override
  String get statCancelled => 'Cancelled';

  @override
  String homeGreeting(String name) {
    return 'Hi $name';
  }

  @override
  String get homeComingUp => 'Coming up';

  @override
  String seatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats left',
      one: '1 seat left',
    );
    return '$_temp0';
  }

  @override
  String get seatsFull => 'Full · waitlist';

  @override
  String seatsTaken(int taken, int capacity) {
    return '$taken of $capacity seats taken';
  }

  @override
  String get detailsEntry => 'Entry';

  @override
  String get detailsFreeShort => 'Free';

  @override
  String get ticketTapToEnlarge =>
      'Tap the code to make it bigger and brighter';

  @override
  String ticketsPastSection(int count) {
    return 'Past events ($count)';
  }

  @override
  String get ticketsNoUpcoming => 'No upcoming tickets';

  @override
  String get notificationsSwipeHint =>
      'Swipe a notification sideways to remove it.';

  @override
  String get notificationsDeleteAll => 'Delete all';

  @override
  String get notificationsDeleteAllTitle => 'Delete all notifications?';

  @override
  String get notificationsDeleteAllBody =>
      'This clears your notification list. Your tickets and events are not affected.';

  @override
  String get notificationsDeleteFailed =>
      'Could not delete. Check your connection and try again.';

  @override
  String get insightsNoSignupsYet => 'No sign-ups yet';

  @override
  String get insightsCameNotCounted =>
      'Came: not counted (open entry, no ticket scan)';

  @override
  String get authVerifyExpiry =>
      'Enter the code within 20 minutes. After that the sign-up is cancelled and you can simply sign up again.';

  @override
  String get authErrWaitForCode =>
      'A code was sent a moment ago. Please wait a minute before asking for another one.';

  @override
  String get authErrSignUpRefused =>
      'This email address can\'t be used to sign up. Contact the UniHub team if you think this is a mistake.';

  @override
  String get adminUnconfirmed => 'Email not confirmed';

  @override
  String get adminRemoveUser => 'Remove user';

  @override
  String adminRemoveUserTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get adminRemoveUserBody =>
      'Their account, tickets, reviews and saved events are deleted. This cannot be undone.';

  @override
  String adminRemoveUserEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Their $count events are deleted too. People registered for upcoming ones are told they are cancelled.',
      one:
          'Their 1 event is deleted too. People registered for it are told it is cancelled.',
    );
    return '$_temp0';
  }

  @override
  String get adminBlockEmail =>
      'Block this email address from signing up again';

  @override
  String adminUserRemoved(String name) {
    return '$name was removed';
  }

  @override
  String get adminBlockedTitle => 'Blocked addresses';

  @override
  String get adminBlockedHint =>
      'These email addresses cannot sign up. Unblocking lets the person create a new account; their old data does not come back.';

  @override
  String get adminNoBlocked => 'No blocked addresses';

  @override
  String get adminUnblock => 'Unblock';

  @override
  String get adminUnblockTitle => 'Unblock this address?';

  @override
  String adminUnblockBody(String email) {
    return '$email will be able to sign up again.';
  }

  @override
  String adminUnblocked(String email) {
    return '$email is unblocked';
  }

  @override
  String get campusNoUniversityTitle => 'Campus events need a university email';

  @override
  String get campusNoUniversityBody =>
      'Your account isn\'t linked to a university, so you see public events only. Sign up with your university email to see your campus events.';
}

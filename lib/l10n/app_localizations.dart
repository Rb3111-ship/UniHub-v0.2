import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'UNIHUB'**
  String get appTitle;

  /// No description provided for @studentRole.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentRole;

  /// No description provided for @plannerRole.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get plannerRole;

  /// No description provided for @toggleRole.
  ///
  /// In en, this message translates to:
  /// **'Switch Role'**
  String get toggleRole;

  /// No description provided for @tenantName.
  ///
  /// In en, this message translates to:
  /// **'University Events Portal'**
  String get tenantName;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get tabTickets;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// No description provided for @tabCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get tabCreateEvent;

  /// No description provided for @tabScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get tabScanner;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @studentHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Campus Events'**
  String get studentHomeTitle;

  /// No description provided for @studentTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get studentTicketsTitle;

  /// No description provided for @studentProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get studentProfileTitle;

  /// No description provided for @plannerDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Analytics'**
  String get plannerDashboardTitle;

  /// No description provided for @plannerCreateEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Event'**
  String get plannerCreateEventTitle;

  /// No description provided for @plannerScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Ticket Scanner'**
  String get plannerScannerTitle;

  /// No description provided for @mockEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Spring Campus Concert'**
  String get mockEventTitle;

  /// No description provided for @mockEventDate.
  ///
  /// In en, this message translates to:
  /// **'June 24, 2026'**
  String get mockEventDate;

  /// No description provided for @mockEventLocation.
  ///
  /// In en, this message translates to:
  /// **'Main Hall'**
  String get mockEventLocation;

  /// No description provided for @mockEventDescription.
  ///
  /// In en, this message translates to:
  /// **'Join us for an evening of live music, food stalls, and community.'**
  String get mockEventDescription;

  /// No description provided for @tabCampusHub.
  ///
  /// In en, this message translates to:
  /// **'Campus Hub'**
  String get tabCampusHub;

  /// No description provided for @tabPublicEvents.
  ///
  /// In en, this message translates to:
  /// **'Public Events'**
  String get tabPublicEvents;

  /// No description provided for @fieldOfficial.
  ///
  /// In en, this message translates to:
  /// **'Is University Official'**
  String get fieldOfficial;

  /// No description provided for @fieldRequireQr.
  ///
  /// In en, this message translates to:
  /// **'Require QR Code Check-in'**
  String get fieldRequireQr;

  /// No description provided for @fieldAllowReviews.
  ///
  /// In en, this message translates to:
  /// **'Allow User Reviews'**
  String get fieldAllowReviews;

  /// No description provided for @headerLivePreview.
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get headerLivePreview;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get categoryMusic;

  /// No description provided for @categoryTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get categoryTech;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryArts.
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get categoryArts;

  /// No description provided for @officialBadge.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL'**
  String get officialBadge;

  /// No description provided for @publicBadge.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC'**
  String get publicBadge;

  /// No description provided for @formFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get formFieldTitle;

  /// No description provided for @formFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location / Room'**
  String get formFieldLocation;

  /// No description provided for @formFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get formFieldCategory;

  /// No description provided for @formFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get formFieldDescription;

  /// No description provided for @formFieldCapacity.
  ///
  /// In en, this message translates to:
  /// **'Participant Capacity'**
  String get formFieldCapacity;

  /// No description provided for @buttonPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish Event'**
  String get buttonPublish;

  /// No description provided for @buttonLeaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave Review'**
  String get buttonLeaveReview;

  /// No description provided for @buttonSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get buttonSubmitReview;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Post-Event Review'**
  String get reviewTitle;

  /// No description provided for @reviewRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get reviewRating;

  /// No description provided for @reviewComment.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get reviewComment;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience about the event...'**
  String get reviewCommentHint;

  /// No description provided for @reviewAttendanceClaim.
  ///
  /// In en, this message translates to:
  /// **'Did you actually attend this event?'**
  String get reviewAttendanceClaim;

  /// No description provided for @reviewVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified Review'**
  String get reviewVerifiedLabel;

  /// No description provided for @reviewUnverifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unverified Review'**
  String get reviewUnverifiedLabel;

  /// No description provided for @reviewWarningDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Unverified data: For internal organizer tracking only.'**
  String get reviewWarningDisclaimer;

  /// No description provided for @reviewSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully!'**
  String get reviewSuccessMsg;

  /// No description provided for @reviewRestrictedMsg.
  ///
  /// In en, this message translates to:
  /// **'Only checked-in attendees can review this event.'**
  String get reviewRestrictedMsg;

  /// No description provided for @dashboardPublicRatings.
  ///
  /// In en, this message translates to:
  /// **'Public Ratings'**
  String get dashboardPublicRatings;

  /// No description provided for @dashboardPrivateFeedback.
  ///
  /// In en, this message translates to:
  /// **'Private Internal Feedback'**
  String get dashboardPrivateFeedback;

  /// No description provided for @dashboardTotalRsvps.
  ///
  /// In en, this message translates to:
  /// **'Total RSVPs'**
  String get dashboardTotalRsvps;

  /// No description provided for @dashboardTotalCheckins.
  ///
  /// In en, this message translates to:
  /// **'Total Check-ins'**
  String get dashboardTotalCheckins;

  /// No description provided for @dashboardAttendanceRate.
  ///
  /// In en, this message translates to:
  /// **'Attendance Rate'**
  String get dashboardAttendanceRate;

  /// No description provided for @prefThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get prefThemeMode;

  /// No description provided for @prefWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper Overlay'**
  String get prefWallpaper;

  /// No description provided for @wallpaperNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get wallpaperNone;

  /// No description provided for @wallpaperGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get wallpaperGrid;

  /// No description provided for @wallpaperSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get wallpaperSunset;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to UNIHUB'**
  String get authWelcome;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Your campus events, in one place.'**
  String get authTagline;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUp;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authDisplayName;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authHaveAccount;

  /// No description provided for @authUniDetected.
  ///
  /// In en, this message translates to:
  /// **'University account detected: {university}'**
  String authUniDetected(String university);

  /// No description provided for @authPublicAccount.
  ///
  /// In en, this message translates to:
  /// **'No university email detected. You will see public events only.'**
  String get authPublicAccount;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authVerifyTitle;

  /// No description provided for @authVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {email}. Enter it below.'**
  String authVerifyBody(String email);

  /// No description provided for @authCode.
  ///
  /// In en, this message translates to:
  /// **'Code from your email'**
  String get authCode;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResend;

  /// No description provided for @authResent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent.'**
  String get authResent;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetTitle;

  /// No description provided for @authResetBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a code.'**
  String get authResetBody;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authResetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get authResetSubmit;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrInvalidEmail;

  /// No description provided for @authErrPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get authErrPasswordShort;

  /// No description provided for @authErrNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get authErrNameRequired;

  /// No description provided for @authErrCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email.'**
  String get authErrCodeRequired;

  /// No description provided for @authErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrGeneric;

  /// No description provided for @authErrBadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrBadCredentials;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email first.'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired.'**
  String get authErrCodeInvalid;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authErrNetwork;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get authProfileLoadFailed;

  /// No description provided for @authRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get authRetry;

  /// No description provided for @eventsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load events.'**
  String get eventsLoadFailed;

  /// No description provided for @eventPublishNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your account is not approved to publish events yet.'**
  String get eventPublishNotAllowed;

  /// No description provided for @eventPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'The event could not be published. Please check the details and try again.'**
  String get eventPublishFailed;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully registered for {title}!'**
  String registerSuccess(String title);

  /// No description provided for @registerWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'{title} is full. You are on the waitlist.'**
  String registerWaitlisted(String title);

  /// No description provided for @registerEventOver.
  ///
  /// In en, this message translates to:
  /// **'This event has already ended.'**
  String get registerEventOver;

  /// No description provided for @registerEventUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This event is not available to you.'**
  String get registerEventUnavailable;

  /// No description provided for @registerPaidNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Paid events are not supported yet.'**
  String get registerPaidNotSupported;

  /// No description provided for @registerFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registerFailed;

  /// No description provided for @ctaWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'Waitlisted'**
  String get ctaWaitlisted;

  /// No description provided for @ticketsWaitlistBadge.
  ///
  /// In en, this message translates to:
  /// **'ON WAITLIST'**
  String get ticketsWaitlistBadge;

  /// No description provided for @ticketsWaitlistNote.
  ///
  /// In en, this message translates to:
  /// **'You will get a ticket automatically if a spot opens up.'**
  String get ticketsWaitlistNote;

  /// No description provided for @ticketCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel registration'**
  String get ticketCancel;

  /// No description provided for @ticketCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel registration?'**
  String get ticketCancelConfirmTitle;

  /// No description provided for @ticketCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your ticket will stop working and your spot goes to the next person.'**
  String get ticketCancelConfirmBody;

  /// No description provided for @ticketCancelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get ticketCancelYes;

  /// No description provided for @ticketCancelNo.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get ticketCancelNo;

  /// No description provided for @ticketCancelled.
  ///
  /// In en, this message translates to:
  /// **'Registration cancelled.'**
  String get ticketCancelled;

  /// No description provided for @ticketCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel. Please try again.'**
  String get ticketCancelFailed;

  /// No description provided for @ticketCancelCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'You are already checked in.'**
  String get ticketCancelCheckedIn;

  /// No description provided for @ticketsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get ticketsRefresh;

  /// No description provided for @reviewErrCheckInRequired.
  ///
  /// In en, this message translates to:
  /// **'You can review this event after you have been checked in.'**
  String get reviewErrCheckInRequired;

  /// No description provided for @reviewErrNotStarted.
  ///
  /// In en, this message translates to:
  /// **'You can review an event after it has started.'**
  String get reviewErrNotStarted;

  /// No description provided for @reviewErrAlready.
  ///
  /// In en, this message translates to:
  /// **'You have already reviewed this event.'**
  String get reviewErrAlready;

  /// No description provided for @reviewErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Reviews are not enabled for this event.'**
  String get reviewErrNotAllowed;

  /// No description provided for @reviewErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Your review could not be sent. Please try again.'**
  String get reviewErrGeneric;

  /// No description provided for @reviewAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get reviewAlreadySubmitted;

  /// No description provided for @reviewOpensAtStart.
  ///
  /// In en, this message translates to:
  /// **'Reviews open when the event starts.'**
  String get reviewOpensAtStart;

  /// No description provided for @detailsNoRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get detailsNoRatings;

  /// No description provided for @detailsEventRating.
  ///
  /// In en, this message translates to:
  /// **'Event rating'**
  String get detailsEventRating;

  /// No description provided for @detailsReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 verified review} other{{count} verified reviews}}'**
  String detailsReviewCount(int count);

  /// No description provided for @dashboardNoEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet. Create one to see your numbers here.'**
  String get dashboardNoEventsYet;

  /// No description provided for @dashboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the dashboard.'**
  String get dashboardLoadFailed;

  /// No description provided for @scanLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scans yet.'**
  String get scanLogEmpty;

  /// No description provided for @scanLogGranted.
  ///
  /// In en, this message translates to:
  /// **'{ticket} checked in'**
  String scanLogGranted(String ticket);

  /// No description provided for @scanLogAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'{ticket} scanned again (already used)'**
  String scanLogAlreadyUsed(String ticket);

  /// No description provided for @scanLogInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid ticket code'**
  String get scanLogInvalid;

  /// No description provided for @scanLogWrongEvent.
  ///
  /// In en, this message translates to:
  /// **'{ticket} belongs to another event'**
  String scanLogWrongEvent(String ticket);

  /// No description provided for @scanLogCancelled.
  ///
  /// In en, this message translates to:
  /// **'{ticket} was cancelled'**
  String scanLogCancelled(String ticket);

  /// No description provided for @dashboardSeatsLine.
  ///
  /// In en, this message translates to:
  /// **'{registered} of {capacity} seats, {checkedIn} checked in'**
  String dashboardSeatsLine(int registered, int capacity, int checkedIn);

  /// No description provided for @dashboardUnlimitedLine.
  ///
  /// In en, this message translates to:
  /// **'{registered} registered (no limit), {checkedIn} checked in'**
  String dashboardUnlimitedLine(int registered, int checkedIn);

  /// No description provided for @dashboardWaitlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} on waitlist'**
  String dashboardWaitlistCount(int count);

  /// No description provided for @agoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String agoDays(int n);

  /// No description provided for @authBrowseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse events without an account'**
  String get authBrowseAsGuest;

  /// No description provided for @guestBanner.
  ///
  /// In en, this message translates to:
  /// **'Browsing as a guest'**
  String get guestBanner;

  /// No description provided for @guestSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get guestSignInTitle;

  /// No description provided for @guestSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Create a free account or sign in to register for events.'**
  String get guestSignInBody;

  /// No description provided for @guestNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get guestNotNow;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get profileEditName;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileNameLabel;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get profileSaved;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get profilePasswordChanged;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get profileDeleteTitle;

  /// No description provided for @profileDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, registrations, tickets and reviews. It cannot be undone.'**
  String get profileDeleteBody;

  /// No description provided for @profileDeleteTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get profileDeleteTypeHint;

  /// No description provided for @profileDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get profileDeleteConfirm;

  /// No description provided for @profileDeleteHasEvents.
  ///
  /// In en, this message translates to:
  /// **'You still own events. Please ask an admin for help before deleting your account.'**
  String get profileDeleteHasEvents;

  /// No description provided for @profileDeleteLastAdmin.
  ///
  /// In en, this message translates to:
  /// **'You are the only platform admin. Make someone else an admin first.'**
  String get profileDeleteLastAdmin;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted. Please try again.'**
  String get profileDeleteFailed;

  /// No description provided for @profileSwitchToStudent.
  ///
  /// In en, this message translates to:
  /// **'Switch to student view'**
  String get profileSwitchToStudent;

  /// No description provided for @profileSwitchToOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Switch to organizer view'**
  String get profileSwitchToOrganizer;

  /// No description provided for @organizerBecomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Become an organizer'**
  String get organizerBecomeTitle;

  /// No description provided for @organizerBecomeBody.
  ///
  /// In en, this message translates to:
  /// **'Publish events for your university or as a business. An admin reviews every request.'**
  String get organizerBecomeBody;

  /// No description provided for @organizerRoleUniversity.
  ///
  /// In en, this message translates to:
  /// **'University organizer'**
  String get organizerRoleUniversity;

  /// No description provided for @organizerRoleCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial / public events'**
  String get organizerRoleCommercial;

  /// No description provided for @organizerOrgName.
  ///
  /// In en, this message translates to:
  /// **'Organization or club name'**
  String get organizerOrgName;

  /// No description provided for @organizerMessage.
  ///
  /// In en, this message translates to:
  /// **'Why do you need access? (optional)'**
  String get organizerMessage;

  /// No description provided for @organizerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get organizerSubmit;

  /// No description provided for @organizerRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. An admin will review it.'**
  String get organizerRequestSent;

  /// No description provided for @organizerStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Your request is waiting for review.'**
  String get organizerStatusPending;

  /// No description provided for @organizerStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Your request was approved. Tap \'Check status\' to unlock organizer tools.'**
  String get organizerStatusApproved;

  /// No description provided for @organizerStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Your last request was not approved.'**
  String get organizerStatusRejected;

  /// No description provided for @organizerCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get organizerCheckStatus;

  /// No description provided for @organizerErrNoUniversity.
  ///
  /// In en, this message translates to:
  /// **'You need a university email address to become a university organizer.'**
  String get organizerErrNoUniversity;

  /// No description provided for @organizerErrPending.
  ///
  /// In en, this message translates to:
  /// **'You already have a request waiting.'**
  String get organizerErrPending;

  /// No description provided for @organizerErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'The request could not be sent. Please check the name and try again.'**
  String get organizerErrGeneric;

  /// No description provided for @tabAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get tabAdmin;

  /// No description provided for @adminRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get adminRequests;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @adminNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests.'**
  String get adminNoRequests;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note for the applicant (optional)'**
  String get adminNoteHint;

  /// No description provided for @adminRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved.'**
  String get adminRequestApproved;

  /// No description provided for @adminRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected.'**
  String get adminRequestRejected;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That action is not allowed or failed.'**
  String get adminActionFailed;

  /// No description provided for @adminSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name or email'**
  String get adminSearchHint;

  /// No description provided for @adminChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get adminChangeRole;

  /// No description provided for @adminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the admin data.'**
  String get adminLoadFailed;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @roleOrganizer.
  ///
  /// In en, this message translates to:
  /// **'University organizer'**
  String get roleOrganizer;

  /// No description provided for @roleCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial planner'**
  String get roleCommercial;

  /// No description provided for @roleTenantAdmin.
  ///
  /// In en, this message translates to:
  /// **'University admin'**
  String get roleTenantAdmin;

  /// No description provided for @rolePlatformAdmin.
  ///
  /// In en, this message translates to:
  /// **'Platform admin'**
  String get rolePlatformAdmin;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @eventEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEditTitle;

  /// No description provided for @eventSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get eventSaveChanges;

  /// No description provided for @eventSaved.
  ///
  /// In en, this message translates to:
  /// **'Event updated.'**
  String get eventSaved;

  /// No description provided for @eventCancelEvent.
  ///
  /// In en, this message translates to:
  /// **'Cancel event'**
  String get eventCancelEvent;

  /// No description provided for @eventCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this event?'**
  String get eventCancelConfirmTitle;

  /// No description provided for @eventCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone with a ticket will see it as cancelled. This cannot be undone.'**
  String get eventCancelConfirmBody;

  /// No description provided for @eventCancelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel event'**
  String get eventCancelYes;

  /// No description provided for @eventCancelledMsg.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled.'**
  String get eventCancelledMsg;

  /// No description provided for @eventCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'The event could not be cancelled.'**
  String get eventCancelFailed;

  /// No description provided for @eventAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add poster image'**
  String get eventAddImage;

  /// No description provided for @eventChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get eventChangeImage;

  /// No description provided for @eventImageTooBig.
  ///
  /// In en, this message translates to:
  /// **'The image is too large (maximum 5 MB).'**
  String get eventImageTooBig;

  /// No description provided for @eventImageBadType.
  ///
  /// In en, this message translates to:
  /// **'Please use a JPG, PNG or WebP image.'**
  String get eventImageBadType;

  /// No description provided for @eventImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be uploaded. Please try again.'**
  String get eventImageUploadFailed;

  /// No description provided for @eventStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get eventStatusCancelled;

  /// No description provided for @ticketEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'This event was cancelled. Your ticket is no longer valid.'**
  String get ticketEventCancelled;

  /// No description provided for @dashboardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get dashboardEdit;

  /// No description provided for @prefSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get prefSection;

  /// No description provided for @accountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionTitle;

  /// No description provided for @universityLabel.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get universityLabel;

  /// No description provided for @universityFromEmail.
  ///
  /// In en, this message translates to:
  /// **'Set automatically from your verified university email.'**
  String get universityFromEmail;

  /// No description provided for @universityNone.
  ///
  /// In en, this message translates to:
  /// **'No university - public account. Sign up with your university email to join one.'**
  String get universityNone;

  /// No description provided for @wallpaperHint.
  ///
  /// In en, this message translates to:
  /// **'Shown behind the main screens in both views. Saved on this device.'**
  String get wallpaperHint;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyTitle;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What we store, who can see it, and your copy'**
  String get privacySubtitle;

  /// No description provided for @privacyWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What UniHub stores about you'**
  String get privacyWhatTitle;

  /// No description provided for @privacyWhatBody.
  ///
  /// In en, this message translates to:
  /// **'Your email address and name, your university (taken from your email domain), your language, the events you registered for with their tickets and check-ins, the reviews you wrote and any organizer requests. Organizers and admins can also add a profile photo.'**
  String get privacyWhatBody;

  /// No description provided for @privacyWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get privacyWhoTitle;

  /// No description provided for @privacyWhoBody.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your registrations and tickets. Organizers see the names of people registered for their own events and the feedback on them. Admins see the account list of their university. Verified reviews are public, without your email. Your password is never visible to anyone.'**
  String get privacyWhoBody;

  /// No description provided for @privacyLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'On this device only'**
  String get privacyLocalTitle;

  /// No description provided for @privacyLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Your theme and wallpaper choice are stored on this device, not in your account.'**
  String get privacyLocalBody;

  /// No description provided for @privacyExport.
  ///
  /// In en, this message translates to:
  /// **'Copy my data'**
  String get privacyExport;

  /// No description provided for @privacyExportDone.
  ///
  /// In en, this message translates to:
  /// **'Your data was copied to the clipboard (JSON). Paste it into a note or email to keep it.'**
  String get privacyExportDone;

  /// No description provided for @privacyExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be loaded. Please try again.'**
  String get privacyExportFailed;

  /// No description provided for @privacyDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'To remove everything for good, use Delete account at the bottom of your profile.'**
  String get privacyDeleteHint;

  /// No description provided for @avatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get avatarChange;

  /// No description provided for @avatarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get avatarRemove;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated.'**
  String get avatarUpdated;

  /// No description provided for @avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed.'**
  String get avatarRemoved;

  /// No description provided for @avatarFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be saved. Use a JPG, PNG or WebP image under 2 MB.'**
  String get avatarFailed;

  /// No description provided for @passwordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get passwordCurrent;

  /// No description provided for @passwordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get passwordRepeat;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The new passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @passwordWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Your current password is not correct.'**
  String get passwordWrongCurrent;

  /// No description provided for @passwordSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'The new password must be different from the current one.'**
  String get passwordSameAsOld;

  /// No description provided for @guestSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Sign up'**
  String get guestSignInButton;

  /// No description provided for @guestOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see this event'**
  String get guestOpenTitle;

  /// No description provided for @guestOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Create a free account or sign in to see event details and register.'**
  String get guestOpenBody;

  /// No description provided for @guestFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Public events'**
  String get guestFeedTitle;

  /// No description provided for @authBackToEvents.
  ///
  /// In en, this message translates to:
  /// **'Back to events'**
  String get authBackToEvents;

  /// No description provided for @eventsEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'No events found in this category.'**
  String get eventsEmptyCategory;

  /// No description provided for @detailsDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get detailsDateTime;

  /// No description provided for @detailsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get detailsLocation;

  /// No description provided for @detailsAbout.
  ///
  /// In en, this message translates to:
  /// **'About this event'**
  String get detailsAbout;

  /// No description provided for @detailsHostedBy.
  ///
  /// In en, this message translates to:
  /// **'Hosted by'**
  String get detailsHostedBy;

  /// No description provided for @detailsGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get detailsGallery;

  /// No description provided for @badgeOfficial.
  ///
  /// In en, this message translates to:
  /// **'{university} OFFICIAL'**
  String badgeOfficial(String university);

  /// No description provided for @badgePublic.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC EVENT'**
  String get badgePublic;

  /// No description provided for @detailsFree.
  ///
  /// In en, this message translates to:
  /// **'FREE ADMISSION'**
  String get detailsFree;

  /// No description provided for @detailsQrRequired.
  ///
  /// In en, this message translates to:
  /// **'QR code ticket required at the door'**
  String get detailsQrRequired;

  /// No description provided for @detailsOpenAdmission.
  ///
  /// In en, this message translates to:
  /// **'Open admission - RSVP so the organizer can plan'**
  String get detailsOpenAdmission;

  /// No description provided for @detailsSeeTickets.
  ///
  /// In en, this message translates to:
  /// **'Your entry QR code is in My Tickets'**
  String get detailsSeeTickets;

  /// No description provided for @detailsTicketReserved.
  ///
  /// In en, this message translates to:
  /// **'TICKET RESERVED'**
  String get detailsTicketReserved;

  /// No description provided for @detailsWaitlistedLabel.
  ///
  /// In en, this message translates to:
  /// **'WAITLISTED'**
  String get detailsWaitlistedLabel;

  /// No description provided for @detailsWaitlistBody.
  ///
  /// In en, this message translates to:
  /// **'You get a ticket automatically if a seat frees up'**
  String get detailsWaitlistBody;

  /// No description provided for @detailsCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'This event was cancelled by the organizer.'**
  String get detailsCancelledBody;

  /// No description provided for @detailsEndedBody.
  ///
  /// In en, this message translates to:
  /// **'This event has already ended.'**
  String get detailsEndedBody;

  /// No description provided for @ctaRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get ctaRegister;

  /// No description provided for @ctaRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get ctaRsvp;

  /// No description provided for @ctaRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get ctaRegistered;

  /// No description provided for @ctaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get ctaUnavailable;

  /// No description provided for @detailsCapacity.
  ///
  /// In en, this message translates to:
  /// **'{count} places'**
  String detailsCapacity(int count);

  /// No description provided for @detailsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit on places'**
  String get detailsUnlimited;

  /// No description provided for @ticketsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get ticketsEmptyTitle;

  /// No description provided for @ticketsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register for an event on the Home tab and your entry QR code appears here.'**
  String get ticketsEmptyBody;

  /// No description provided for @ticketCheckedInBadge.
  ///
  /// In en, this message translates to:
  /// **'CHECKED IN'**
  String get ticketCheckedInBadge;

  /// No description provided for @ticketConfirmedBadge.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get ticketConfirmedBadge;

  /// No description provided for @ticketEndedBadge.
  ///
  /// In en, this message translates to:
  /// **'ENDED'**
  String get ticketEndedBadge;

  /// No description provided for @ticketLabelDate.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get ticketLabelDate;

  /// No description provided for @ticketLabelLocation.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get ticketLabelLocation;

  /// No description provided for @ticketLabelEntry.
  ///
  /// In en, this message translates to:
  /// **'ENTRY'**
  String get ticketLabelEntry;

  /// No description provided for @ticketEntryQr.
  ///
  /// In en, this message translates to:
  /// **'QR check-in'**
  String get ticketEntryQr;

  /// No description provided for @ticketEntryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open entry'**
  String get ticketEntryOpen;

  /// No description provided for @ticketLabelId.
  ///
  /// In en, this message translates to:
  /// **'TICKET'**
  String get ticketLabelId;

  /// No description provided for @ticketScannedOk.
  ///
  /// In en, this message translates to:
  /// **'Ticket scanned - enjoy the event!'**
  String get ticketScannedOk;

  /// No description provided for @ticketShowAtEntrance.
  ///
  /// In en, this message translates to:
  /// **'Show this QR code at the entrance'**
  String get ticketShowAtEntrance;

  /// No description provided for @scanChooseEventFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the event you are scanning for first.'**
  String get scanChooseEventFirst;

  /// No description provided for @scanNotUnihub.
  ///
  /// In en, this message translates to:
  /// **'This is not a UniHub ticket.'**
  String get scanNotUnihub;

  /// No description provided for @scanGranted.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}! Checked in.'**
  String scanGranted(String name);

  /// No description provided for @scanAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'{name} was already checked in.'**
  String scanAlreadyUsed(String name);

  /// No description provided for @scanWrongEvent.
  ///
  /// In en, this message translates to:
  /// **'This ticket is for a different event.'**
  String get scanWrongEvent;

  /// No description provided for @scanCancelled.
  ///
  /// In en, this message translates to:
  /// **'This ticket was cancelled.'**
  String get scanCancelled;

  /// No description provided for @scanInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid ticket.'**
  String get scanInvalid;

  /// No description provided for @scanNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to scan tickets for this event.'**
  String get scanNotAllowed;

  /// No description provided for @scanOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and scan again.'**
  String get scanOffline;

  /// No description provided for @scanGuestFallback.
  ///
  /// In en, this message translates to:
  /// **'guest'**
  String get scanGuestFallback;

  /// No description provided for @scanAccessGranted.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get scanAccessGranted;

  /// No description provided for @scanAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get scanAccessDenied;

  /// No description provided for @scanClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get scanClose;

  /// No description provided for @scanEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter ticket code'**
  String get scanEnterCode;

  /// No description provided for @scanEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the code from the ticket'**
  String get scanEnterCodeHint;

  /// No description provided for @scanCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get scanCheckIn;

  /// No description provided for @scanNoEvents.
  ///
  /// In en, this message translates to:
  /// **'You have no events to scan for. Create one to start checking in guests.'**
  String get scanNoEvents;

  /// No description provided for @scanEventsFailed.
  ///
  /// In en, this message translates to:
  /// **'Your events could not be loaded.'**
  String get scanEventsFailed;

  /// No description provided for @scanPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a ticket QR code'**
  String get scanPointCamera;

  /// No description provided for @scanPointCameraDemo.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a ticket QR code or tap \'Demo scan\''**
  String get scanPointCameraDemo;

  /// No description provided for @scanDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Demo scan'**
  String get scanDemoButton;

  /// No description provided for @scanProcessing.
  ///
  /// In en, this message translates to:
  /// **'Checking ticket...'**
  String get scanProcessing;

  /// No description provided for @scanTorch.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get scanTorch;

  /// No description provided for @scanManual.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get scanManual;

  /// No description provided for @formHeader.
  ///
  /// In en, this message translates to:
  /// **'Event details'**
  String get formHeader;

  /// No description provided for @formTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spring Hackathon 2026'**
  String get formTitleHint;

  /// No description provided for @formTitleError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title (3 to 140 characters).'**
  String get formTitleError;

  /// No description provided for @formCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories (up to 3)'**
  String get formCategories;

  /// No description provided for @formCategoriesMax.
  ///
  /// In en, this message translates to:
  /// **'You can select up to 3 categories.'**
  String get formCategoriesMax;

  /// No description provided for @categoryAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get categoryAcademic;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @formLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Main Hall, Building B'**
  String get formLocationHint;

  /// No description provided for @formLocationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a location.'**
  String get formLocationError;

  /// No description provided for @formStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get formStarts;

  /// No description provided for @formEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get formEnds;

  /// No description provided for @formChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get formChange;

  /// No description provided for @formEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The event must end after it starts.'**
  String get formEndBeforeStart;

  /// No description provided for @formStartInPast.
  ///
  /// In en, this message translates to:
  /// **'The start time is in the past. Please pick a later time.'**
  String get formStartInPast;

  /// No description provided for @formNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No attendee limit'**
  String get formNoLimit;

  /// No description provided for @formOfficialTitle.
  ///
  /// In en, this message translates to:
  /// **'Official university event'**
  String get formOfficialTitle;

  /// No description provided for @formOfficialBody.
  ///
  /// In en, this message translates to:
  /// **'Only members of {university} can see it.'**
  String formOfficialBody(String university);

  /// No description provided for @formPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Public event'**
  String get formPublicTitle;

  /// No description provided for @formPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone can see it, also without an account.'**
  String get formPublicBody;

  /// No description provided for @formDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Schedule, speakers, rules ...'**
  String get formDescriptionHint;

  /// No description provided for @eventPublished.
  ///
  /// In en, this message translates to:
  /// **'Event published.'**
  String get eventPublished;

  /// No description provided for @previewTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your event title'**
  String get previewTitlePlaceholder;

  /// No description provided for @previewLocationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get previewLocationPlaceholder;

  /// No description provided for @previewDescPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your description appears here.'**
  String get previewDescPlaceholder;

  /// No description provided for @previewReviewsOn.
  ///
  /// In en, this message translates to:
  /// **'Reviews on'**
  String get previewReviewsOn;

  /// No description provided for @reviewErrCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a comment.'**
  String get reviewErrCommentRequired;

  /// No description provided for @dashboardAttendanceByEvent.
  ///
  /// In en, this message translates to:
  /// **'Attendance by event'**
  String get dashboardAttendanceByEvent;

  /// No description provided for @dashboardRecentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent scans'**
  String get dashboardRecentScans;

  /// No description provided for @dashboardActiveEvents.
  ///
  /// In en, this message translates to:
  /// **'Active events'**
  String get dashboardActiveEvents;

  /// No description provided for @dashboardNoPublicRatings.
  ///
  /// In en, this message translates to:
  /// **'No public ratings yet.'**
  String get dashboardNoPublicRatings;

  /// No description provided for @dashboardNoPrivateFeedback.
  ///
  /// In en, this message translates to:
  /// **'No private feedback yet.'**
  String get dashboardNoPrivateFeedback;

  /// No description provided for @dashboardClaimedAttendance.
  ///
  /// In en, this message translates to:
  /// **'Says they attended'**
  String get dashboardClaimedAttendance;

  /// No description provided for @wallpaperDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get wallpaperDots;

  /// No description provided for @wallpaperWaves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get wallpaperWaves;

  /// No description provided for @wallpaperAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get wallpaperAurora;

  /// No description provided for @wallpaperOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get wallpaperOcean;

  /// No description provided for @wallpaperBubbles.
  ///
  /// In en, this message translates to:
  /// **'Bubbles'**
  String get wallpaperBubbles;

  /// No description provided for @formCustomCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Your own category (optional)'**
  String get formCustomCategoryLabel;

  /// No description provided for @formCustomCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Yoga, Gaming, Careers'**
  String get formCustomCategoryHint;

  /// No description provided for @formCustomCategoryError.
  ///
  /// In en, this message translates to:
  /// **'Use 2 to 30 letters or numbers.'**
  String get formCustomCategoryError;

  /// No description provided for @posterShowFull.
  ///
  /// In en, this message translates to:
  /// **'Show the whole poster'**
  String get posterShowFull;

  /// No description provided for @posterClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get posterClose;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'No app found to open this, so it was copied.'**
  String get linkCopied;

  /// No description provided for @detailsContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact & links'**
  String get detailsContactTitle;

  /// No description provided for @contactWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get contactWebsite;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmail;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhone;

  /// No description provided for @formContactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact & links (optional)'**
  String get formContactSection;

  /// No description provided for @formContactHint.
  ///
  /// In en, this message translates to:
  /// **'Students see these as tappable links on the event page.'**
  String get formContactHint;

  /// No description provided for @formWebsiteError.
  ///
  /// In en, this message translates to:
  /// **'Enter a web address like www.example.org.'**
  String get formWebsiteError;

  /// No description provided for @formPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number (digits, spaces and + - / ( ) only).'**
  String get formPhoneError;

  /// No description provided for @otherCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'More categories'**
  String get otherCategoriesTitle;

  /// No description provided for @otherCategoriesAll.
  ///
  /// In en, this message translates to:
  /// **'All other events'**
  String get otherCategoriesAll;

  /// No description provided for @otherCategoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other categories yet.'**
  String get otherCategoriesEmpty;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search events, categories, organizers'**
  String get searchHint;

  /// No description provided for @searchOpen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchOpen;

  /// No description provided for @searchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No events match your search.'**
  String get searchNoResults;

  /// No description provided for @byOrganizer.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String byOrganizer(String name);

  /// No description provided for @authConfirmFirst.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email first. We sent you a new code.'**
  String get authConfirmFirst;

  /// No description provided for @authChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? Start again'**
  String get authChangeEmail;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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

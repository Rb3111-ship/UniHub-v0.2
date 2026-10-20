// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'UNIHUB';

  @override
  String get studentRole => 'Student';

  @override
  String get plannerRole => 'Planer';

  @override
  String get toggleRole => 'Rolle wechseln';

  @override
  String get tenantName => 'Universität-Veranstaltungsportal';

  @override
  String get tabHome => 'Startseite';

  @override
  String get tabTickets => 'Meine Tickets';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabCreateEvent => 'Event erstellen';

  @override
  String get tabScanner => 'Scanner';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get studentHomeTitle => 'Kommende Campus-Events';

  @override
  String get studentTicketsTitle => 'Meine Tickets';

  @override
  String get studentProfileTitle => 'Profileinstellungen';

  @override
  String get plannerDashboardTitle => 'Veranstaltungsanalyse';

  @override
  String get plannerCreateEventTitle => 'Neues Event erstellen';

  @override
  String get plannerScannerTitle => 'QR-Ticket-Scanner';

  @override
  String get mockEventTitle => 'Frühlings-Campus-Konzert';

  @override
  String get mockEventDate => '24. Juni 2026';

  @override
  String get mockEventLocation => 'Hauptsaal';

  @override
  String get mockEventDescription =>
      'Erleben Sie einen Abend voller Live-Musik, Essensständen und Gemeinschaft.';

  @override
  String get tabCampusHub => 'Campus-Hub';

  @override
  String get tabPublicEvents => 'Öffentliche Events';

  @override
  String get fieldOfficial => 'Offizielles Uni-Event';

  @override
  String get fieldRequireQr => 'QR-Code-Check-in erforderlich';

  @override
  String get fieldAllowReviews => 'Nutzerbewertungen erlauben';

  @override
  String get headerLivePreview => 'Live-Vorschau';

  @override
  String get categoryAll => 'Alle';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryTech => 'Technik';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryArts => 'Kunst';

  @override
  String get officialBadge => 'OFFIZIELL';

  @override
  String get publicBadge => 'ÖFFENTLICH';

  @override
  String get formFieldTitle => 'Veranstaltungstitel';

  @override
  String get formFieldLocation => 'Ort / Raum';

  @override
  String get formFieldCategory => 'Kategorie';

  @override
  String get formFieldDescription => 'Beschreibung';

  @override
  String get formFieldCapacity => 'Teilnehmerkapazität';

  @override
  String get buttonPublish => 'Event veröffentlichen';

  @override
  String get buttonLeaveReview => 'Bewertung abgeben';

  @override
  String get buttonSubmitReview => 'Bewertung absenden';

  @override
  String get reviewTitle => 'Event-Bewertung';

  @override
  String get reviewRating => 'Bewertung';

  @override
  String get reviewComment => 'Kommentare';

  @override
  String get reviewCommentHint =>
      'Teilen Sie Ihre Erfahrungen über die Veranstaltung...';

  @override
  String get reviewAttendanceClaim =>
      'Haben Sie dieses Event tatsächlich besucht?';

  @override
  String get reviewVerifiedLabel => 'Verifizierte Bewertung';

  @override
  String get reviewUnverifiedLabel => 'Unverifizierte Bewertung';

  @override
  String get reviewWarningDisclaimer =>
      'Unverifizierte Daten: Nur zur internen Nachverfolgung der Organisatoren.';

  @override
  String get reviewSuccessMsg => 'Bewertung erfolgreich übermittelt!';

  @override
  String get reviewRestrictedMsg =>
      'Nur eingecheckte Teilnehmer können dieses Event bewerten.';

  @override
  String get dashboardPublicRatings => 'Öffentliche Bewertungen';

  @override
  String get dashboardPrivateFeedback => 'Privates internes Feedback';

  @override
  String get dashboardTotalRsvps => 'Zusagen gesamt';

  @override
  String get dashboardTotalCheckins => 'Check-ins gesamt';

  @override
  String get dashboardAttendanceRate => 'Anwesenheitsquote';

  @override
  String get prefThemeMode => 'Design-Modus';

  @override
  String get prefWallpaper => 'Hintergrundmuster';

  @override
  String get wallpaperNone => 'Keines';

  @override
  String get wallpaperGrid => 'Gitter';

  @override
  String get wallpaperSunset => 'Sonnenuntergang';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get authWelcome => 'Willkommen bei UNIHUB';

  @override
  String get authTagline => 'Deine Campus-Events an einem Ort.';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authSignUp => 'Konto erstellen';

  @override
  String get authEmail => 'E-Mail';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authDisplayName => 'Dein Name';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authNoAccount => 'Neu hier? Konto erstellen';

  @override
  String get authHaveAccount => 'Schon ein Konto? Anmelden';

  @override
  String authUniDetected(String university) {
    return 'Hochschulkonto erkannt: $university';
  }

  @override
  String get authPublicAccount =>
      'Keine Hochschul-E-Mail erkannt. Du siehst nur öffentliche Events.';

  @override
  String get authVerifyTitle => 'Prüfe deine E-Mails';

  @override
  String authVerifyBody(String email) {
    return 'Wir haben einen Code an $email gesendet. Gib ihn unten ein.';
  }

  @override
  String get authCode => 'Code aus deiner E-Mail';

  @override
  String get authVerify => 'Bestätigen';

  @override
  String get authResend => 'Code erneut senden';

  @override
  String get authResent => 'Ein neuer Code wurde gesendet.';

  @override
  String get authResetTitle => 'Passwort zurücksetzen';

  @override
  String get authResetBody =>
      'Gib deine E-Mail ein, wir senden dir einen Code.';

  @override
  String get authSendCode => 'Code senden';

  @override
  String get authNewPassword => 'Neues Passwort';

  @override
  String get authResetSubmit => 'Neues Passwort speichern';

  @override
  String get authBackToSignIn => 'Zurück zur Anmeldung';

  @override
  String get authErrInvalidEmail => 'Gib eine gültige E-Mail-Adresse ein.';

  @override
  String get authErrPasswordShort =>
      'Das Passwort muss mindestens 8 Zeichen haben.';

  @override
  String get authErrNameRequired => 'Bitte gib deinen Namen ein.';

  @override
  String get authErrCodeRequired => 'Gib den Code aus deiner E-Mail ein.';

  @override
  String get authErrGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get authErrBadCredentials => 'E-Mail oder Passwort ist falsch.';

  @override
  String get authErrEmailNotConfirmed => 'Bitte bestätige zuerst deine E-Mail.';

  @override
  String get authErrCodeInvalid => 'Der Code ist falsch oder abgelaufen.';

  @override
  String get authErrNetwork =>
      'Keine Verbindung. Prüfe dein Internet und versuche es erneut.';

  @override
  String get authSignOut => 'Abmelden';

  @override
  String get authProfileLoadFailed => 'Profil konnte nicht geladen werden.';

  @override
  String get authRetry => 'Erneut versuchen';
}

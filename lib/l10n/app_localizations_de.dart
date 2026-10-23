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

  @override
  String get eventsLoadFailed => 'Events konnten nicht geladen werden.';

  @override
  String get eventPublishNotAllowed =>
      'Dein Konto ist noch nicht zum Veröffentlichen von Events freigegeben.';

  @override
  String get eventPublishFailed =>
      'Das Event konnte nicht veröffentlicht werden. Bitte prüfe die Angaben und versuche es erneut.';

  @override
  String registerSuccess(String title) {
    return 'Erfolgreich für $title angemeldet!';
  }

  @override
  String registerWaitlisted(String title) {
    return '$title ist voll. Du stehst auf der Warteliste.';
  }

  @override
  String get registerEventOver => 'Dieses Event ist bereits vorbei.';

  @override
  String get registerEventUnavailable =>
      'Dieses Event ist für dich nicht verfügbar.';

  @override
  String get registerPaidNotSupported =>
      'Kostenpflichtige Events werden noch nicht unterstützt.';

  @override
  String get registerFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get ctaWaitlisted => 'Warteliste';

  @override
  String get ticketsWaitlistBadge => 'WARTELISTE';

  @override
  String get ticketsWaitlistNote =>
      'Du bekommst automatisch ein Ticket, sobald ein Platz frei wird.';

  @override
  String get ticketCancel => 'Anmeldung stornieren';

  @override
  String get ticketCancelConfirmTitle => 'Anmeldung stornieren?';

  @override
  String get ticketCancelConfirmBody =>
      'Dein Ticket wird ungültig und dein Platz geht an die nächste Person.';

  @override
  String get ticketCancelYes => 'Ja, stornieren';

  @override
  String get ticketCancelNo => 'Behalten';

  @override
  String get ticketCancelled => 'Anmeldung storniert.';

  @override
  String get ticketCancelFailed =>
      'Stornierung nicht möglich. Bitte versuche es erneut.';

  @override
  String get ticketCancelCheckedIn => 'Du bist bereits eingecheckt.';

  @override
  String get ticketsRefresh => 'Aktualisieren';

  @override
  String get reviewErrCheckInRequired =>
      'Du kannst dieses Event bewerten, nachdem du eingecheckt wurdest.';

  @override
  String get reviewErrNotStarted =>
      'Du kannst ein Event bewerten, sobald es begonnen hat.';

  @override
  String get reviewErrAlready => 'Du hast dieses Event bereits bewertet.';

  @override
  String get reviewErrNotAllowed =>
      'Für dieses Event sind keine Bewertungen aktiviert.';

  @override
  String get reviewErrGeneric =>
      'Deine Bewertung konnte nicht gesendet werden. Bitte versuche es erneut.';

  @override
  String get reviewAlreadySubmitted => 'Bewertung abgegeben';

  @override
  String get reviewOpensAtStart =>
      'Bewertungen sind ab Beginn des Events möglich.';

  @override
  String get detailsNoRatings => 'Noch keine Bewertungen';

  @override
  String get detailsEventRating => 'Event-Bewertung';

  @override
  String detailsReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geprüfte Bewertungen',
      one: '1 geprüfte Bewertung',
    );
    return '$_temp0';
  }

  @override
  String get dashboardNoEventsYet =>
      'Noch keine Events. Erstelle eines, um hier Zahlen zu sehen.';

  @override
  String get dashboardLoadFailed =>
      'Das Dashboard konnte nicht geladen werden.';

  @override
  String get scanLogEmpty => 'Noch keine Scans.';

  @override
  String scanLogGranted(String ticket) {
    return '$ticket eingecheckt';
  }

  @override
  String scanLogAlreadyUsed(String ticket) {
    return '$ticket erneut gescannt (bereits benutzt)';
  }

  @override
  String get scanLogInvalid => 'Ungültiger Ticketcode';

  @override
  String scanLogWrongEvent(String ticket) {
    return '$ticket gehört zu einem anderen Event';
  }

  @override
  String scanLogCancelled(String ticket) {
    return '$ticket wurde storniert';
  }

  @override
  String dashboardSeatsLine(int registered, int capacity, int checkedIn) {
    return '$registered von $capacity Plätzen, $checkedIn eingecheckt';
  }

  @override
  String dashboardUnlimitedLine(int registered, int checkedIn) {
    return '$registered angemeldet (unbegrenzt), $checkedIn eingecheckt';
  }

  @override
  String dashboardWaitlistCount(int count) {
    return '$count auf der Warteliste';
  }

  @override
  String get agoJustNow => 'gerade eben';

  @override
  String agoMinutes(int n) {
    return 'vor $n Min.';
  }

  @override
  String agoHours(int n) {
    return 'vor $n Std.';
  }

  @override
  String agoDays(int n) {
    return 'vor $n T.';
  }

  @override
  String get authBrowseAsGuest => 'Events ohne Konto ansehen';

  @override
  String get guestBanner => 'Du stöberst als Gast';

  @override
  String get guestSignInTitle => 'Melde dich an, um fortzufahren';

  @override
  String get guestSignInBody =>
      'Erstelle ein kostenloses Konto oder melde dich an, um dich für Events anzumelden.';

  @override
  String get guestNotNow => 'Jetzt nicht';

  @override
  String get profileEditName => 'Namen ändern';

  @override
  String get profileNameLabel => 'Dein Name';

  @override
  String get profileSave => 'Speichern';

  @override
  String get profileCancel => 'Abbrechen';

  @override
  String get profileSaved => 'Gespeichert.';

  @override
  String get profileChangePassword => 'Passwort ändern';

  @override
  String get profilePasswordChanged => 'Passwort geändert.';

  @override
  String get profileDeleteAccount => 'Konto löschen';

  @override
  String get profileDeleteTitle => 'Dein Konto löschen?';

  @override
  String get profileDeleteBody =>
      'Dadurch werden dein Konto, deine Anmeldungen, Tickets und Bewertungen endgültig gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get profileDeleteTypeHint => 'Tippe DELETE zur Bestätigung';

  @override
  String get profileDeleteConfirm => 'Endgültig löschen';

  @override
  String get profileDeleteHasEvents =>
      'Du besitzt noch Events. Bitte bitte einen Admin um Hilfe, bevor du dein Konto löschst.';

  @override
  String get profileDeleteLastAdmin =>
      'Du bist der einzige Plattform-Admin. Ernenne zuerst jemand anderen zum Admin.';

  @override
  String get profileDeleteFailed =>
      'Das Konto konnte nicht gelöscht werden. Bitte versuche es erneut.';

  @override
  String get profileSwitchToStudent => 'Zur Studierendenansicht wechseln';

  @override
  String get profileSwitchToOrganizer => 'Zur Organisatoransicht wechseln';

  @override
  String get organizerBecomeTitle => 'Organisator werden';

  @override
  String get organizerBecomeBody =>
      'Veröffentliche Events für deine Hochschule oder als Unternehmen. Jede Anfrage wird von einem Admin geprüft.';

  @override
  String get organizerRoleUniversity => 'Hochschul-Organisator';

  @override
  String get organizerRoleCommercial => 'Kommerzielle / öffentliche Events';

  @override
  String get organizerOrgName => 'Name der Organisation oder des Clubs';

  @override
  String get organizerMessage => 'Wofür brauchst du den Zugang? (optional)';

  @override
  String get organizerSubmit => 'Anfrage senden';

  @override
  String get organizerRequestSent =>
      'Anfrage gesendet. Ein Admin wird sie prüfen.';

  @override
  String get organizerStatusPending => 'Deine Anfrage wartet auf Prüfung.';

  @override
  String get organizerStatusApproved =>
      'Deine Anfrage wurde genehmigt. Tippe auf \'Status prüfen\', um die Organisator-Werkzeuge freizuschalten.';

  @override
  String get organizerStatusRejected =>
      'Deine letzte Anfrage wurde nicht genehmigt.';

  @override
  String get organizerCheckStatus => 'Status prüfen';

  @override
  String get organizerErrNoUniversity =>
      'Du brauchst eine Hochschul-E-Mail-Adresse, um Hochschul-Organisator zu werden.';

  @override
  String get organizerErrPending => 'Du hast bereits eine offene Anfrage.';

  @override
  String get organizerErrGeneric =>
      'Die Anfrage konnte nicht gesendet werden. Bitte prüfe den Namen und versuche es erneut.';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get adminRequests => 'Anfragen';

  @override
  String get adminUsers => 'Nutzer';

  @override
  String get adminNoRequests => 'Keine Anfragen.';

  @override
  String get adminApprove => 'Genehmigen';

  @override
  String get adminReject => 'Ablehnen';

  @override
  String get adminNoteHint =>
      'Hinweis für die antragstellende Person (optional)';

  @override
  String get adminRequestApproved => 'Genehmigt.';

  @override
  String get adminRequestRejected => 'Abgelehnt.';

  @override
  String get adminActionFailed =>
      'Diese Aktion ist nicht erlaubt oder fehlgeschlagen.';

  @override
  String get adminSearchHint => 'Name oder E-Mail suchen';

  @override
  String get adminChangeRole => 'Rolle ändern';

  @override
  String get adminLoadFailed => 'Die Admin-Daten konnten nicht geladen werden.';

  @override
  String get roleStudent => 'Studierende';

  @override
  String get roleOrganizer => 'Hochschul-Organisator';

  @override
  String get roleCommercial => 'Kommerzieller Planer';

  @override
  String get roleTenantAdmin => 'Hochschul-Admin';

  @override
  String get rolePlatformAdmin => 'Plattform-Admin';

  @override
  String get statusPending => 'Offen';

  @override
  String get statusApproved => 'Genehmigt';

  @override
  String get statusRejected => 'Abgelehnt';

  @override
  String get eventEditTitle => 'Event bearbeiten';

  @override
  String get eventSaveChanges => 'Änderungen speichern';

  @override
  String get eventSaved => 'Event aktualisiert.';

  @override
  String get eventCancelEvent => 'Event absagen';

  @override
  String get eventCancelConfirmTitle => 'Dieses Event absagen?';

  @override
  String get eventCancelConfirmBody =>
      'Alle mit einem Ticket sehen es als abgesagt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get eventCancelYes => 'Ja, Event absagen';

  @override
  String get eventCancelledMsg => 'Event abgesagt.';

  @override
  String get eventCancelFailed => 'Das Event konnte nicht abgesagt werden.';

  @override
  String get eventAddImage => 'Posterbild hinzufügen';

  @override
  String get eventChangeImage => 'Bild ändern';

  @override
  String get eventImageTooBig => 'Das Bild ist zu groß (maximal 5 MB).';

  @override
  String get eventImageBadType =>
      'Bitte verwende ein JPG-, PNG- oder WebP-Bild.';

  @override
  String get eventImageUploadFailed =>
      'Das Bild konnte nicht hochgeladen werden. Bitte versuche es erneut.';

  @override
  String get eventStatusCancelled => 'ABGESAGT';

  @override
  String get ticketEventCancelled =>
      'Dieses Event wurde abgesagt. Dein Ticket ist nicht mehr gültig.';

  @override
  String get dashboardEdit => 'Bearbeiten';
}

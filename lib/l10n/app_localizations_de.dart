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
  String get tabCreateEvent => 'Erstellen';

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

  @override
  String get prefSection => 'Einstellungen';

  @override
  String get accountSectionTitle => 'Konto';

  @override
  String get universityLabel => 'Hochschule';

  @override
  String get universityFromEmail =>
      'Wird automatisch über deine bestätigte Hochschul-E-Mail festgelegt.';

  @override
  String get universityNone =>
      'Keine Hochschule - öffentliches Konto. Registriere dich mit deiner Hochschul-E-Mail, um beizutreten.';

  @override
  String get wallpaperHint =>
      'Wird in beiden Ansichten hinter den Hauptseiten angezeigt. Auf diesem Gerät gespeichert.';

  @override
  String get privacyTitle => 'Datenschutz & Daten';

  @override
  String get privacySubtitle =>
      'Was wir speichern, wer es sieht, und deine Kopie';

  @override
  String get privacyWhatTitle => 'Was UniHub über dich speichert';

  @override
  String get privacyWhatBody =>
      'Deine E-Mail-Adresse und deinen Namen, deine Hochschule (aus deiner E-Mail-Domain), deine Sprache, die Events, für die du dich angemeldet hast, mit Tickets und Check-ins, deine Bewertungen und Organisator-Anfragen. Organisatoren und Admins können zusätzlich ein Profilfoto hinzufügen.';

  @override
  String get privacyWhoTitle => 'Wer es sehen kann';

  @override
  String get privacyWhoBody =>
      'Nur du siehst deine Anmeldungen und Tickets. Organisatoren sehen die Namen der Angemeldeten ihrer eigenen Events und das Feedback dazu. Admins sehen die Kontoliste ihrer Hochschule. Verifizierte Bewertungen sind öffentlich, ohne deine E-Mail. Dein Passwort sieht niemand.';

  @override
  String get privacyLocalTitle => 'Nur auf diesem Gerät';

  @override
  String get privacyLocalBody =>
      'Design und Hintergrund werden auf diesem Gerät gespeichert, nicht in deinem Konto.';

  @override
  String get privacyExport => 'Meine Daten kopieren';

  @override
  String get privacyExportDone =>
      'Deine Daten wurden in die Zwischenablage kopiert (JSON). Füge sie in eine Notiz oder E-Mail ein.';

  @override
  String get privacyExportFailed =>
      'Deine Daten konnten nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get privacyDeleteHint =>
      'Um alles endgültig zu entfernen, nutze „Konto löschen“ unten in deinem Profil.';

  @override
  String get avatarChange => 'Foto ändern';

  @override
  String get avatarRemove => 'Foto entfernen';

  @override
  String get avatarUpdated => 'Foto aktualisiert.';

  @override
  String get avatarRemoved => 'Foto entfernt.';

  @override
  String get avatarFailed =>
      'Das Foto konnte nicht gespeichert werden. Nutze ein JPG-, PNG- oder WebP-Bild unter 2 MB.';

  @override
  String get passwordCurrent => 'Aktuelles Passwort';

  @override
  String get passwordRepeat => 'Neues Passwort wiederholen';

  @override
  String get passwordMismatch => 'Die neuen Passwörter stimmen nicht überein.';

  @override
  String get passwordWrongCurrent =>
      'Dein aktuelles Passwort ist nicht korrekt.';

  @override
  String get passwordSameAsOld =>
      'Das neue Passwort muss sich vom aktuellen unterscheiden.';

  @override
  String get guestSignInButton => 'Anmelden / Registrieren';

  @override
  String get guestOpenTitle => 'Melde dich an, um dieses Event zu sehen';

  @override
  String get guestOpenBody =>
      'Erstelle ein kostenloses Konto oder melde dich an, um Details zu sehen und dich anzumelden.';

  @override
  String get guestFeedTitle => 'Öffentliche Events';

  @override
  String get authBackToEvents => 'Zurück zu den Events';

  @override
  String get eventsEmptyCategory => 'Keine Events in dieser Kategorie.';

  @override
  String get detailsDateTime => 'Datum & Uhrzeit';

  @override
  String get detailsLocation => 'Ort';

  @override
  String get detailsAbout => 'Über dieses Event';

  @override
  String get detailsHostedBy => 'Veranstaltet von';

  @override
  String get detailsGallery => 'Galerie';

  @override
  String badgeOfficial(String university) {
    return '$university OFFIZIELL';
  }

  @override
  String get badgePublic => 'ÖFFENTLICHES EVENT';

  @override
  String get detailsFree => 'EINTRITT FREI';

  @override
  String get detailsQrRequired => 'QR-Code-Ticket am Einlass erforderlich';

  @override
  String get detailsOpenAdmission =>
      'Freier Einlass - sag zu, damit der Veranstalter planen kann';

  @override
  String get detailsSeeTickets =>
      'Dein Einlass-QR-Code ist unter „Meine Tickets“';

  @override
  String get detailsTicketReserved => 'TICKET RESERVIERT';

  @override
  String get detailsWaitlistedLabel => 'WARTELISTE';

  @override
  String get detailsWaitlistBody =>
      'Du bekommst automatisch ein Ticket, wenn ein Platz frei wird';

  @override
  String get detailsCancelledBody =>
      'Dieses Event wurde vom Veranstalter abgesagt.';

  @override
  String get detailsEndedBody => 'Dieses Event ist bereits vorbei.';

  @override
  String get ctaRegister => 'Anmelden';

  @override
  String get ctaRsvp => 'Zusagen';

  @override
  String get ctaRegistered => 'Angemeldet';

  @override
  String get ctaUnavailable => 'Nicht verfügbar';

  @override
  String detailsCapacity(int count) {
    return '$count Plätze';
  }

  @override
  String get detailsUnlimited => 'Keine Platzbegrenzung';

  @override
  String get ticketsEmptyTitle => 'Noch keine Tickets';

  @override
  String get ticketsEmptyBody =>
      'Melde dich im Tab Start für ein Event an - dein Einlass-QR-Code erscheint dann hier.';

  @override
  String get ticketCheckedInBadge => 'EINGECHECKT';

  @override
  String get ticketConfirmedBadge => 'BESTÄTIGT';

  @override
  String get ticketEndedBadge => 'VORBEI';

  @override
  String get ticketLabelDate => 'DATUM';

  @override
  String get ticketLabelLocation => 'ORT';

  @override
  String get ticketLabelEntry => 'EINLASS';

  @override
  String get ticketEntryQr => 'QR-Check-in';

  @override
  String get ticketEntryOpen => 'Freier Einlass';

  @override
  String get ticketLabelId => 'TICKET';

  @override
  String get ticketScannedOk => 'Ticket gescannt - viel Spaß!';

  @override
  String get ticketShowAtEntrance => 'Zeig diesen QR-Code am Einlass';

  @override
  String get scanChooseEventFirst =>
      'Wähle zuerst das Event, für das du scannst.';

  @override
  String get scanNotUnihub => 'Das ist kein UniHub-Ticket.';

  @override
  String scanGranted(String name) {
    return 'Willkommen, $name! Eingecheckt.';
  }

  @override
  String scanAlreadyUsed(String name) {
    return '$name wurde bereits eingecheckt.';
  }

  @override
  String get scanWrongEvent => 'Dieses Ticket gilt für ein anderes Event.';

  @override
  String get scanCancelled => 'Dieses Ticket wurde storniert.';

  @override
  String get scanInvalid => 'Ungültiges Ticket.';

  @override
  String get scanNotAllowed =>
      'Du darfst für dieses Event keine Tickets scannen.';

  @override
  String get scanOffline =>
      'Server nicht erreichbar. Prüfe deine Verbindung und scanne erneut.';

  @override
  String get scanGuestFallback => 'Gast';

  @override
  String get scanAccessGranted => 'Einlass gewährt';

  @override
  String get scanAccessDenied => 'Einlass verweigert';

  @override
  String get scanClose => 'Schließen';

  @override
  String get scanEnterCode => 'Ticket-Code eingeben';

  @override
  String get scanEnterCodeHint => 'Code vom Ticket einfügen';

  @override
  String get scanCheckIn => 'Einchecken';

  @override
  String get scanNoEvents =>
      'Du hast keine Events zum Scannen. Erstelle eins, um Gäste einzuchecken.';

  @override
  String get scanEventsFailed => 'Deine Events konnten nicht geladen werden.';

  @override
  String get scanPointCamera =>
      'Richte die Kamera auf den QR-Code eines Tickets';

  @override
  String get scanPointCameraDemo =>
      'Richte die Kamera auf einen QR-Code oder tippe auf „Demo-Scan“';

  @override
  String get scanDemoButton => 'Demo-Scan';

  @override
  String get scanProcessing => 'Ticket wird geprüft...';

  @override
  String get scanTorch => 'Taschenlampe';

  @override
  String get scanManual => 'Code manuell eingeben';

  @override
  String get formHeader => 'Event-Details';

  @override
  String get formTitleHint => 'z. B. Frühlings-Hackathon 2026';

  @override
  String get formTitleError => 'Bitte gib einen Titel ein (3 bis 140 Zeichen).';

  @override
  String get formCategories => 'Kategorien (bis zu 3)';

  @override
  String get formCategoriesMax => 'Du kannst bis zu 3 Kategorien wählen.';

  @override
  String get categoryAcademic => 'Akademisch';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String get formLocationHint => 'z. B. Audimax, Gebäude B';

  @override
  String get formLocationError => 'Bitte gib einen Ort ein.';

  @override
  String get formStarts => 'Beginn';

  @override
  String get formEnds => 'Ende';

  @override
  String get formChange => 'Ändern';

  @override
  String get formEndBeforeStart => 'Das Event muss nach dem Beginn enden.';

  @override
  String get formStartInPast =>
      'Der Beginn liegt in der Vergangenheit. Bitte wähle eine spätere Zeit.';

  @override
  String get formNoLimit => 'Keine Teilnehmerbegrenzung';

  @override
  String get formOfficialTitle => 'Offizielles Hochschul-Event';

  @override
  String formOfficialBody(String university) {
    return 'Nur Mitglieder von $university können es sehen.';
  }

  @override
  String get formPublicTitle => 'Öffentliches Event';

  @override
  String get formPublicBody => 'Alle können es sehen, auch ohne Konto.';

  @override
  String get formDescriptionHint => 'Ablauf, Speaker, Regeln ...';

  @override
  String get eventPublished => 'Event veröffentlicht.';

  @override
  String get previewTitlePlaceholder => 'Dein Event-Titel';

  @override
  String get previewLocationPlaceholder => 'Ort';

  @override
  String get previewDescPlaceholder => 'Deine Beschreibung erscheint hier.';

  @override
  String get previewReviewsOn => 'Bewertungen an';

  @override
  String get reviewErrCommentRequired => 'Bitte schreib einen Kommentar.';

  @override
  String get dashboardAttendanceByEvent => 'Teilnahme nach Event';

  @override
  String get dashboardRecentScans => 'Letzte Scans';

  @override
  String get dashboardActiveEvents => 'Aktive Events';

  @override
  String get dashboardNoPublicRatings => 'Noch keine öffentlichen Bewertungen.';

  @override
  String get dashboardNoPrivateFeedback => 'Noch kein privates Feedback.';

  @override
  String get dashboardClaimedAttendance => 'Gibt Teilnahme an';

  @override
  String get wallpaperDots => 'Punkte';

  @override
  String get wallpaperWaves => 'Wellen';

  @override
  String get wallpaperAurora => 'Polarlicht';

  @override
  String get wallpaperOcean => 'Ozean';

  @override
  String get wallpaperBubbles => 'Blasen';

  @override
  String get formCustomCategoryLabel => 'Eigene Kategorie (optional)';

  @override
  String get formCustomCategoryHint => 'z. B. Yoga, Gaming, Karriere';

  @override
  String get formCustomCategoryError =>
      'Bitte 2 bis 30 Buchstaben oder Zahlen verwenden.';

  @override
  String get posterShowFull => 'Ganzes Plakat anzeigen';

  @override
  String get posterClose => 'Schließen';

  @override
  String get linkCopied => 'Keine App zum Öffnen gefunden, daher kopiert.';

  @override
  String get detailsContactTitle => 'Kontakt & Links';

  @override
  String get contactWebsite => 'Webseite';

  @override
  String get contactEmail => 'E-Mail';

  @override
  String get contactPhone => 'Telefon';

  @override
  String get formContactSection => 'Kontakt & Links (optional)';

  @override
  String get formContactHint =>
      'Studierende sehen das als antippbare Links auf der Event-Seite.';

  @override
  String get formWebsiteError =>
      'Bitte eine Webadresse wie www.example.org eingeben.';

  @override
  String get formPhoneError =>
      'Bitte eine Telefonnummer eingeben (nur Ziffern, Leerzeichen und + - / ( )).';

  @override
  String get otherCategoriesTitle => 'Weitere Kategorien';

  @override
  String get otherCategoriesAll => 'Alle anderen Events';

  @override
  String get otherCategoriesEmpty => 'Noch keine weiteren Kategorien.';

  @override
  String get searchHint => 'Events, Kategorien, Veranstalter suchen';

  @override
  String get searchOpen => 'Suchen';

  @override
  String get searchClose => 'Suche schließen';

  @override
  String get searchNoResults => 'Keine Events passen zu deiner Suche.';

  @override
  String byOrganizer(String name) {
    return 'von $name';
  }

  @override
  String get authConfirmFirst =>
      'Bitte bestätige zuerst deine E-Mail. Wir haben dir einen neuen Code geschickt.';

  @override
  String get authChangeEmail => 'Falsche E-Mail? Neu beginnen';
}

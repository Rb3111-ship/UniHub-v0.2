/// Who organizes an event, as shown to students.
class EventHost {
  final String name;
  final String? organization; // club / company from the approved organizer request
  final String? photoUrl;

  const EventHost({required this.name, this.organization, this.photoUrl});

  /// The organization if there is one, otherwise the person's name.
  String get label => (organization?.trim().isNotEmpty ?? false) ? organization!.trim() : name;

  /// Lower-case text used by the event search.
  String get searchText => '${name.toLowerCase()} ${(organization ?? '').toLowerCase()}';
}

/// Checks and cleans the optional contact fields of an event. The database
/// applies the same rules, so these only give earlier, friendlier feedback.
class EventContact {
  static final _email = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  static final _phone = RegExp(r'^\+?[0-9][0-9 ()/-]{4,28}[0-9]$');
  static final _website = RegExp(r'^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]{1,5})?(/[^\s<>"]*)?$');

  /// Empty input means "no value" (null). Returns '' if the input is invalid.
  static String? email(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    return v.length <= 254 && _email.hasMatch(v) ? v : '';
  }

  static String? phone(String input) {
    final v = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '').length;
    return _phone.hasMatch(v) && digits >= 5 && digits <= 20 ? v : '';
  }

  /// Adds https:// when it is missing; plain http links are upgraded to https.
  static String? website(String input) {
    var v = input.trim();
    if (v.isEmpty) return null;
    if (v.toLowerCase().startsWith('http://')) v = 'https://${v.substring(7)}';
    if (!v.toLowerCase().startsWith('https://')) {
      if (v.contains('://') || v.contains(':') && !v.contains('.')) return '';
      v = 'https://$v';
    }
    return v.length <= 500 && _website.hasMatch(v) ? v : '';
  }
}

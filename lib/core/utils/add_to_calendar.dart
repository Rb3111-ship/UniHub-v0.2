import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import 'open_link.dart';

/// Puts the event into the user's calendar. On Android the phone's calendar app
/// opens with everything filled in; elsewhere (web) Google Calendar opens.
Future<void> addToCalendar(BuildContext context, Event event) async {
  final notes = [
    if (event.description.trim().isNotEmpty) event.description.trim(),
    if (event.websiteUrl != null) event.websiteUrl!,
  ].join('\n\n');

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final opened = await cal.Add2Calendar.addEvent2Cal(cal.Event(
        title: event.title,
        description: notes,
        location: event.location,
        startDate: event.date,
        endDate: event.endDate,
      ));
      if (opened) return;
    } catch (_) {
      // No calendar app: fall back to Google Calendar in the browser.
    }
  }
  if (!context.mounted) return;
  final uri = googleCalendarLink(event, notes);
  await openLink(context, uri, uri.toString());
}

/// A Google Calendar "add event" link (times in UTC).
Uri googleCalendarLink(Event event, String notes) {
  String stamp(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': event.title,
    'dates': '${stamp(event.date)}/${stamp(event.endDate)}',
    'location': event.location,
    if (notes.isNotEmpty) 'details': notes.length > 1500 ? '${notes.substring(0, 1500)}...' : notes,
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "9:30 AM" or "09:30" depending on the device's 24-hour setting.
String formatMinuteOfDay(BuildContext context, int minute) {
  final tod = TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    tod,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// "25 min", "1 h", "1 h 30 min".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Friendly relative wording, used to fight time blindness:
/// "in 12 min", "in 1 h 5 min", "now".
String formatUntil(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins <= 0) return 'now';
  return 'in ${formatDuration(mins)}';
}

/// "12:04" style countdown.
String formatClock(Duration d) {
  final total = d.inSeconds.clamp(0, 359999);
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String formatDayTitle(DateTime day, DateTime today) {
  final diff = DateTime(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEEE, d MMM').format(day);
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Still up';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

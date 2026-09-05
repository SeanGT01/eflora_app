import 'package:intl/intl.dart';

const _phtOffset = Duration(hours: 8);

/// Parse API datetime strings. Naive ISO from Flask is stored/sent as UTC.
DateTime? parseBackendDateTime(String? value) {
  if (value == null) return null;
  final raw = value.trim();
  if (raw.isEmpty) return null;

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    final parts = raw.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  if (RegExp(r'[zZ]|[+\-]\d{2}:\d{2}$').hasMatch(raw)) {
    return DateTime.parse(raw).toUtc();
  }

  return DateTime.parse('${raw}Z');
}

/// UTC instant → Philippine wall clock for display (UTC+8).
DateTime toPhilippineWallClock(DateTime dt) {
  final utc = dt.isUtc ? dt : dt.toUtc();
  return utc.add(_phtOffset);
}

String formatPhilippineDateTime(DateTime? dt, String pattern) {
  if (dt == null) return '';
  return DateFormat(pattern).format(toPhilippineWallClock(dt));
}

String formatPhilippineDateTimeFromIso(String? iso, String pattern) {
  final dt = parseBackendDateTime(iso);
  if (dt == null) return '';
  return formatPhilippineDateTime(dt, pattern);
}

DateTime philippineNow() => toPhilippineWallClock(DateTime.now().toUtc());

bool isDifferentPhilippineDay(String a, String b) {
  final da = parseBackendDateTime(a);
  final db = parseBackendDateTime(b);
  if (da == null || db == null) return a != b;
  final pa = toPhilippineWallClock(da);
  final pb = toPhilippineWallClock(db);
  return pa.year != pb.year || pa.month != pb.month || pa.day != pb.day;
}

String formatPhilippineChatDayLabel(String? iso) {
  final dt = parseBackendDateTime(iso);
  if (dt == null) return '';
  final d = toPhilippineWallClock(dt);
  final now = philippineNow();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (d.year == yesterday.year &&
      d.month == yesterday.month &&
      d.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat('M/d/yyyy').format(d);
}

String formatPhilippineTime12hFromIso(String? iso) {
  return formatPhilippineDateTimeFromIso(iso, 'h:mm a');
}

/// Relative age from a backend ISO timestamp (UTC instant).
String formatRelativeFromIso(String? iso, {bool compactDate = false}) {
  final dt = parseBackendDateTime(iso);
  if (dt == null) return '';
  final diff = DateTime.now().toUtc().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (compactDate && diff.inDays >= 7) {
    return DateFormat('M/d').format(toPhilippineWallClock(dt));
  }
  return '${diff.inDays}d';
}

/// Calendar date from YYYY-MM-DD (no day shift — delivery date is local).
String formatPhilippineDateOnly(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '';
  final raw = iso.trim();
  try {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      final parts = raw.split('-');
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return DateFormat('MMM dd, yyyy').format(d);
    }
    final dt = parseBackendDateTime(raw);
    if (dt == null) return raw;
    return DateFormat('MMM dd, yyyy').format(toPhilippineWallClock(dt));
  } catch (_) {
    return iso;
  }
}

/// Store clock time in PH (`08:00`, `17:30`) → `8:00 AM` / `5:30 PM`.
String formatPhilippineClock12h(String? time24) {
  if (time24 == null) return '';
  final raw = time24.trim();
  if (raw.isEmpty) return '';
  if (RegExp(r'(am|pm)', caseSensitive: false).hasMatch(raw)) return raw;
  try {
    final pattern = raw.split(':').length >= 3 ? 'H:mm:ss' : 'H:mm';
    final parsed = DateFormat(pattern).parse(raw);
    return DateFormat('h:mm a').format(parsed);
  } catch (_) {
    return raw;
  }
}

/// e.g. "08:00-12:00" → "8:00 AM - 12:00 PM"
String formatDeliveryTimeSlot(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return '';
  try {
    final parts = timeStr.split('-');
    if (parts.length != 2) return formatPhilippineClock12h(timeStr);

    final start = formatPhilippineClock12h(parts[0].trim());
    final end = formatPhilippineClock12h(parts[1].trim());
    if (start.isEmpty || end.isEmpty) return timeStr;
    return '$start - $end';
  } catch (_) {
    return timeStr;
  }
}

String formatRequestedDelivery(String? date, String? time) {
  if (date == null || date.isEmpty) return '';
  final dateFormatted = formatPhilippineDateOnly(date);
  final timeFormatted =
      time != null && time.isNotEmpty ? formatDeliveryTimeSlot(time) : '';
  if (timeFormatted.isEmpty) return dateFormatted;
  return '$dateFormatted, $timeFormatted';
}

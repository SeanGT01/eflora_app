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

/// e.g. "08:00-12:00" → "8:00am-12:00pm"
String formatDeliveryTimeSlot(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return '';
  try {
    final parts = timeStr.split('-');
    if (parts.length != 2) return timeStr;

    final startTime = DateFormat('H:mm').parse(parts[0].trim());
    final endTime = DateFormat('H:mm').parse(parts[1].trim());

    final startFormatted = DateFormat('h:mma').format(startTime).toLowerCase();
    final endFormatted = DateFormat('h:mma').format(endTime).toLowerCase();

    return '$startFormatted-$endFormatted';
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

import 'package:flutter/services.dart';

/// Letters (incl. common accented), space, hyphen, apostrophe.
final _nameChar = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿÑñ' \-]");
final _namePattern = RegExp(
  r"^[A-Za-zÀ-ÖØ-öø-ÿÑñ]+(?:[ '\-][A-Za-zÀ-ÖØ-öø-ÿÑñ]+)*$",
);

const int kFirstNameMax = 50;
const int kLastNameMax = 30;
const int kFullNameMax = kFirstNameMax + 1 + kLastNameMax;

class PersonNameInputFormatter extends TextInputFormatter {
  const PersonNameInputFormatter({this.maxLength = kFirstNameMax});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = FilteringTextInputFormatter.allow(_nameChar)
        .formatEditUpdate(oldValue, newValue);
    if (filtered.text.length <= maxLength) return filtered;
    // At the cap: ignore extra keystrokes instead of inserting then clipping.
    if (oldValue.text.length >= maxLength &&
        filtered.text.length > oldValue.text.length) {
      return oldValue;
    }
    return LengthLimitingTextInputFormatter(
      maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
    ).formatEditUpdate(oldValue, filtered);
  }
}

String? validatePersonName(String? raw, {required String field, int maxLen = kFirstNameMax}) {
  final text = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '$field is required';
  if (text.length < 2) return '$field must be at least 2 letters';
  if (text.length > maxLen) return '$field must be at most $maxLen characters';
  if (!_namePattern.hasMatch(text)) {
    return '$field can only contain letters, spaces, hyphens, and apostrophes';
  }
  return null;
}

String? validateFullName(String? raw) {
  final text = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return 'Full name is required';
  if (text.length > kFullNameMax) {
    return 'Full name must be at most $kFullNameMax characters';
  }
  if (!_namePattern.hasMatch(text) || !text.contains(' ')) {
    return 'Enter your first and last name using letters only';
  }
  return null;
}

import 'package:flutter/services.dart';

/// Forces email-style input to lowercase as the user types (ASCII emails).
class LowercaseEmailInputFormatter extends TextInputFormatter {
  const LowercaseEmailInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.toLowerCase();
    if (t == newValue.text) return newValue;
    return TextEditingValue(
      text: t,
      selection: newValue.selection,
    );
  }
}

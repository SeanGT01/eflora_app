import 'package:flutter/material.dart';

/// Height of the rider tab bar content (excludes system safe-area inset).
const double kRiderNavBarHeight = 62;

/// Bottom padding so scrollable content clears the floating nav + home indicator.
double riderShellBottomInset(BuildContext context, {double extra = 16}) {
  return MediaQuery.paddingOf(context).bottom + kRiderNavBarHeight + extra;
}

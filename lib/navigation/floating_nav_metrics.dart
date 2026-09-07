import 'package:flutter/material.dart';

/// Foodpanda-style floating pill bottom nav sizing.
const kFloatingNavBarHeight = 52.0;
const kFloatingNavHorizontalInset = 16.0;
const kFloatingNavBottomGap = 12.0;

/// Scroll/content padding so the last item clears the floating nav.
double floatingNavScrollClearance(BuildContext context, {double extra = 12}) {
  return MediaQuery.viewPaddingOf(context).bottom +
      kFloatingNavBottomGap +
      kFloatingNavBarHeight +
      extra;
}

/// Distance from the physical screen bottom to the top of the floating nav.
double floatingNavTopFromBottom(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom +
      kFloatingNavBottomGap +
      kFloatingNavBarHeight;
}

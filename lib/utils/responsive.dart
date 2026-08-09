import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Phone-first layout scale based on a 390×844 design (iPhone 14 / common mid size).
///
/// Use [AppResponsive.of] or the [BuildContext] extensions (`context.s`, `context.sp`)
/// so paddings, icon sizes, and type scale across small → large phones without
/// needing a per-screen MediaQuery copy-paste.
class AppResponsive {
  AppResponsive._(this.size)
      : scale = (size.width / designWidth).clamp(minScale, maxScale),
        heightScale = (size.height / designHeight).clamp(0.82, 1.18);

  static const double designWidth = 390;
  static const double designHeight = 844;
  static const double minScale = 0.82;
  static const double maxScale = 1.18;

  final Size size;
  final double scale;
  final double heightScale;

  factory AppResponsive.of(BuildContext context) {
    return AppResponsive._(MediaQuery.sizeOf(context));
  }

  /// Scale a design-token length (padding, icon, radius-ish sizes).
  double s(double value) => value * scale;

  /// Scale type; slightly softer than layout scale so text stays readable
  /// on tiny phones without exploding on large ones.
  double sp(double value) {
    final t = ((scale - 1.0) * 0.65) + 1.0;
    return value * t.clamp(0.88, 1.12);
  }

  bool get isCompact => size.width < 360;
  bool get isWidePhone => size.width >= 410;

  /// Horizontal page gutter used by home / account / search.
  double get gutter => s(20).clamp(14.0, 24.0);

  /// Comfortable bottom inset under floating nav / chat FAB.
  double bottomContentInset(BuildContext context, {double extra = 72}) {
    return MediaQuery.paddingOf(context).bottom + s(extra);
  }

  /// Product grid metrics that keep cards readable on narrow screens.
  int get productCrossAxisCount => size.width >= 700 ? 3 : 2;

  double get productCrossSpacing => s(12).clamp(8.0, 16.0);

  double get productMainSpacing => s(12).clamp(8.0, 16.0);

  /// Taller cards on narrow devices so title + price don't clip.
  double get productAspectRatio {
    if (size.width < 340) return 0.62;
    if (size.width < 380) return 0.65;
    return 0.68;
  }

  EdgeInsets pagePadding({
    double top = 0,
    double bottom = 0,
    double? horizontal,
  }) {
    final h = horizontal ?? gutter;
    return EdgeInsets.fromLTRB(h, s(top), h, s(bottom));
  }
}

extension AppResponsiveContext on BuildContext {
  AppResponsive get responsive => AppResponsive.of(this);

  /// Layout length scale.
  double s(double value) => responsive.s(value);

  /// Font size scale.
  double sp(double value) => responsive.sp(value);

  double get pageGutter => responsive.gutter;
}

/// Clamps system font scaling so large accessibility sizes don't shatter layouts,
/// while still honoring moderate user preference.
MediaQueryData clampAppTextScaler(MediaQueryData data) {
  return data.copyWith(
    textScaler: data.textScaler.clamp(
      minScaleFactor: 0.90,
      maxScaleFactor: 1.30,
    ),
  );
}

/// Convenience for FittedBox labels that must never ellipsize mid-word.
Widget responsiveLabel(
  BuildContext context, {
  required String text,
  required TextStyle style,
  int maxLines = 2,
  TextAlign textAlign = TextAlign.center,
  double? width,
}) {
  final w = width ?? math.min(context.s(100), MediaQuery.sizeOf(context).width * 0.28);
  return SizedBox(
    width: w,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: SizedBox(
        width: w,
        child: Text(
          text,
          maxLines: maxLines,
          softWrap: true,
          textAlign: textAlign,
          style: style,
        ),
      ),
    ),
  );
}

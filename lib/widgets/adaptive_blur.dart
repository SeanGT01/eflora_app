import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_quality.dart';

/// Applies [BackdropFilter] only on rich-quality devices.
class AdaptiveBlur extends StatelessWidget {
  const AdaptiveBlur({
    super.key,
    required this.child,
    this.sigma = 16,
  });

  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    if (!AppQuality.instance.useBlur || sigma <= 0) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

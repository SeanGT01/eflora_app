import 'package:flutter/material.dart';

/// Wraps a horizontally scrollable widget with a soft gradient fading mask
/// on its left and right edges.
class HorizontalFadingEdge extends StatelessWidget {
  final Widget child;
  final double fadeWidth;

  const HorizontalFadingEdge({
    super.key,
    required this.child,
    this.fadeWidth = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        if (bounds.width <= 0) {
          return const LinearGradient(
            colors: [Colors.transparent, Colors.transparent],
          ).createShader(bounds);
        }
        final double effectiveFade = fadeWidth.clamp(0.0, bounds.width / 3);
        final double stopStart = effectiveFade / bounds.width;
        final double stopEnd = 1.0 - stopStart;

        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [
            0.0,
            stopStart,
            stopEnd,
            1.0,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

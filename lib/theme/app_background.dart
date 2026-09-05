import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Warm cream page fill with blush→mint wash and soft radial orbs.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _AtmosphereWash()),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AtmosphereWash extends StatelessWidget {
  const _AtmosphereWash();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.pageCream),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.9, -0.55),
                end: Alignment(0.95, 0.8),
                colors: [
                  Color.fromRGBO(242, 196, 206, 0.18),
                  Color.fromRGBO(255, 252, 248, 0.92),
                  Color.fromRGBO(255, 253, 250, 0.96),
                  Color.fromRGBO(248, 250, 246, 0.92),
                  Color.fromRGBO(196, 214, 198, 0.16),
                ],
                stops: [0.0, 0.22, 0.50, 0.78, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.84, -0.60),
                  radius: 0.85,
                  colors: [
                    Color.fromRGBO(242, 196, 206, 0.16),
                    Color.fromRGBO(242, 196, 206, 0.0),
                  ],
                  stops: [0.0, 0.70],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.84, -0.40),
                  radius: 0.80,
                  colors: [
                    Color.fromRGBO(122, 158, 126, 0.12),
                    Color.fromRGBO(122, 158, 126, 0.0),
                  ],
                  stops: [0.0, 0.70],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.70),
                  radius: 0.90,
                  colors: [
                    Color.fromRGBO(212, 120, 138, 0.06),
                    Color.fromRGBO(212, 120, 138, 0.0),
                  ],
                  stops: [0.0, 0.65],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.40, -0.80),
                  radius: 0.70,
                  colors: [
                    Color.fromRGBO(196, 214, 198, 0.10),
                    Color.fromRGBO(196, 214, 198, 0.0),
                  ],
                  stops: [0.0, 0.70],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

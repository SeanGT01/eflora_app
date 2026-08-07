import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_quality.dart';
import 'app_theme.dart';

/// Recreates the website landing atmosphere from `index.html`:
/// warm `#fffcf8` base, 105° blush→mint diagonal wash, soft radial orbs,
/// and slow-drifting white flowers behind the content (gated on low-end).
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.showFlowers = true,
    this.flowerCount = 10,
  });

  final Widget child;
  final bool showFlowers;
  final int flowerCount;

  @override
  Widget build(BuildContext context) {
    final q = AppQuality.instance;
    final allowFlowers = showFlowers && q.useFlowers;
    final count = allowFlowers ? flowerCount : 0;

    return Stack(
      children: [
        const Positioned.fill(child: _AtmosphereWash()),
        if (allowFlowers && count > 0)
          Positioned.fill(
            child: IgnorePointer(child: _DriftingFlowers(count: count)),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AtmosphereWash extends StatelessWidget {
  const _AtmosphereWash();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.pageCream),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // linear-gradient(105deg, blush → cream → mint) over #fffcf8
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.9, -0.55),
                end: const Alignment(0.95, 0.8),
                colors: [
                  const Color.fromRGBO(242, 196, 206, 0.18),
                  const Color.fromRGBO(255, 252, 248, 0.92),
                  const Color.fromRGBO(255, 253, 250, 0.96),
                  const Color.fromRGBO(248, 250, 246, 0.92),
                  const Color.fromRGBO(196, 214, 198, 0.16),
                ],
                stops: const [0.0, 0.22, 0.50, 0.78, 1.0],
              ),
            ),
          ),
          // Radial washes matching body::after on the landing page
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.84, -0.60),
                  radius: 0.85,
                  colors: [
                    const Color.fromRGBO(242, 196, 206, 0.16),
                    const Color.fromRGBO(242, 196, 206, 0.0),
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.84, -0.40),
                  radius: 0.80,
                  colors: [
                    const Color.fromRGBO(122, 158, 126, 0.12),
                    const Color.fromRGBO(122, 158, 126, 0.0),
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.70),
                  radius: 0.90,
                  colors: [
                    const Color.fromRGBO(212, 120, 138, 0.06),
                    const Color.fromRGBO(212, 120, 138, 0.0),
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.40, -0.80),
                  radius: 0.70,
                  colors: [
                    const Color.fromRGBO(196, 214, 198, 0.10),
                    const Color.fromRGBO(196, 214, 198, 0.0),
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placement of one background flower, mirroring the site's scattered layout.
class _FlowerSpec {
  const _FlowerSpec({
    required this.alignment,
    required this.size,
    required this.opacity,
    required this.rotation,
    required this.petals,
    required this.periodMs,
    required this.phase,
  });

  final Alignment alignment;
  final double size;
  final double opacity;
  final double rotation;
  final int petals;
  final int periodMs;
  final double phase;
}

const List<_FlowerSpec> _flowerSpecs = [
  _FlowerSpec(alignment: Alignment(-0.96, -0.92), size: 132, opacity: 0.28, rotation: -28, petals: 5, periodMs: 22000, phase: 0.0),
  _FlowerSpec(alignment: Alignment(-0.72, -0.42), size: 104, opacity: 0.20, rotation: 42, petals: 6, periodMs: 24000, phase: 0.22),
  _FlowerSpec(alignment: Alignment(-1.02, 0.08), size: 142, opacity: 0.26, rotation: 16, petals: 5, periodMs: 20000, phase: 0.5),
  _FlowerSpec(alignment: Alignment(-0.55, 0.88), size: 96, opacity: 0.18, rotation: -52, petals: 6, periodMs: 26000, phase: 0.32),
  _FlowerSpec(alignment: Alignment(0.92, -0.78), size: 148, opacity: 0.28, rotation: 33, petals: 5, periodMs: 21000, phase: 0.14),
  _FlowerSpec(alignment: Alignment(1.04, -0.12), size: 102, opacity: 0.20, rotation: -41, petals: 5, periodMs: 23000, phase: 0.52),
  _FlowerSpec(alignment: Alignment(0.7, 0.5), size: 116, opacity: 0.25, rotation: 58, petals: 6, periodMs: 19000, phase: 0.37),
  _FlowerSpec(alignment: Alignment(0.98, 0.94), size: 92, opacity: 0.18, rotation: -19, petals: 5, periodMs: 25000, phase: 0.6),
  _FlowerSpec(alignment: Alignment(-0.3, -0.2), size: 74, opacity: 0.16, rotation: 71, petals: 5, periodMs: 27000, phase: 0.08),
  _FlowerSpec(alignment: Alignment(0.25, 0.72), size: 80, opacity: 0.14, rotation: -63, petals: 6, periodMs: 18000, phase: 0.78),
];

class _DriftingFlowers extends StatefulWidget {
  const _DriftingFlowers({required this.count});

  final int count;

  @override
  State<_DriftingFlowers> createState() => _DriftingFlowersState();
}

class _DriftingFlowersState extends State<_DriftingFlowers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specs = _flowerSpecs.take(widget.count.clamp(0, _flowerSpecs.length));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            for (final spec in specs)
              Align(
                alignment: spec.alignment,
                child: _buildFlower(spec),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFlower(_FlowerSpec spec) {
    final t = (_controller.value + spec.phase) % 1.0;
    final wave = math.sin(t * 2 * math.pi);
    final dx = 6 * wave;
    final dy = -8 * wave;
    final scale = 1 + 0.03 * ((wave + 1) / 2);
    final angle = (spec.rotation + 5 * ((wave + 1) / 2)) * math.pi / 180;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: spec.opacity,
            child: CustomPaint(
              size: Size.square(spec.size),
              painter: _FlowerPainter(petals: spec.petals),
            ),
          ),
        ),
      ),
    );
  }
}

/// White five/six-petal bloom with a warm golden centre, matching the SVG
/// flowers used on the website background.
class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({required this.petals});

  final int petals;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 100;

    final petalStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * unit
      ..color = const Color(0xFFD9C4C2);

    final shadow = Paint()
      ..color = const Color(0x38785A64)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final step = 2 * math.pi / petals;

    for (var i = 0; i < petals; i++) {
      final angle = i * step;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final petalRect = Rect.fromCenter(
        center: Offset(0, -22 * unit),
        width: 30 * unit,
        height: 48 * unit,
      );

      final petalFill = Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.7,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F6), Color(0xFFF3E4E2)],
          stops: [0.0, 0.7, 1.0],
        ).createShader(petalRect);

      canvas.drawOval(petalRect.shift(Offset(0, 2 * unit)), shadow);
      canvas.drawOval(petalRect, petalFill);
      canvas.drawOval(petalRect, petalStroke);
      canvas.restore();
    }

    final centreRect = Rect.fromCircle(center: center, radius: 11 * unit);
    final centreFill = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFE9A8), Color(0xFFE8C56A)],
      ).createShader(centreRect);

    canvas.drawCircle(center, 11 * unit, centreFill);
    canvas.drawCircle(
      center,
      11 * unit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit
        ..color = const Color(0xFFE0C070),
    );
    canvas.drawCircle(
      center,
      4 * unit,
      Paint()..color = const Color(0xE6FFF6D6),
    );
  }

  @override
  bool shouldRepaint(_FlowerPainter oldDelegate) => oldDelegate.petals != petals;
}

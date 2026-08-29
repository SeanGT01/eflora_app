import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Google Maps–style rider puck with a heading wedge when [headingDegrees] is set.
class RiderHeadingMarker extends StatelessWidget {
  final double? headingDegrees;
  final Color color;
  final double size;

  const RiderHeadingMarker({
    super.key,
    this.headingDegrees,
    this.color = const Color(0xFF3498db),
    this.size = 52,
  });

  /// Resolve heading from GPS or movement between two fixes.
  static double? resolveHeading({
    required LatLng? previous,
    required LatLng current,
    Position? position,
    double? previousHeading,
  }) {
    double? heading;

    if (position != null && position.speed >= 0.8) {
      final gpsHeading = position.heading;
      if (gpsHeading >= 0 && gpsHeading <= 360) {
        heading = gpsHeading;
      }
    }

    if (previous != null) {
      final movedMeters = _haversineMeters(previous, current);
      if (movedMeters >= 6) {
        final bearing = bearingBetween(previous, current);
        heading = heading == null
            ? bearing
            : lerpAngle(heading, bearing, 0.45);
      }
    }

    if (heading != null && previousHeading != null) {
      heading = lerpAngle(previousHeading, heading, 0.35);
    }

    return heading;
  }

  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double lerpAngle(double from, double to, double t) {
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * t + 360) % 360;
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.asin(math.sqrt(h));
  }

  @override
  Widget build(BuildContext context) {
    final heading = headingDegrees;
    final dotSize = size * 0.62;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (heading != null)
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: CustomPaint(
                size: Size(size, size),
                painter: _HeadingConePainter(color: color.withOpacity(0.28)),
              ),
            ),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: heading == null
                ? Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: dotSize * 0.48,
                  )
                : null,
          ),
          if (heading != null)
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: CustomPaint(
                size: Size(size * 0.55, size * 0.55),
                painter: const _HeadingArrowPainter(),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  final Color color;

  _HeadingConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const sweep = 62 * math.pi / 180;
    const start = -math.pi / 2 - sweep / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2),
      start,
      sweep,
      true,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _HeadingConePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeadingArrowPainter extends CustomPainter {
  const _HeadingArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(cx, 0)
      ..lineTo(size.width, size.height * 0.72)
      ..lineTo(cx, size.height * 0.46)
      ..lineTo(0, size.height * 0.72)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

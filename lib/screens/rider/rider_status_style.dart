import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Delivery status tints matching the website's retinted badge palette.
class RiderStatusStyle {
  const RiderStatusStyle({required this.foreground, required this.background});

  final Color foreground;
  final Color background;

  static const _assigned = RiderStatusStyle(
    foreground: Color(0xFF6A4A9A),
    background: Color(0x66D2BEF0),
  );
  static const _onDelivery = RiderStatusStyle(
    foreground: Color(0xFFA04060),
    background: Color(0x66FFBED2),
  );
  static const _delivered = RiderStatusStyle(
    foreground: Color(0xFF3F6B4E),
    background: Color(0x80C8E6D2),
  );
  static const _cancelled = RiderStatusStyle(
    foreground: Color(0xFF9B1C1C),
    background: Color(0x1FC24E68),
  );
  static const _pending = RiderStatusStyle(
    foreground: Color(0xFFA06030),
    background: Color(0x73FFD2B4),
  );

  static RiderStatusStyle of(String? status) {
    switch (status) {
      case 'accepted':
      case 'assigned':
      case 'done_preparing':
      case 'preparing':
        return _assigned;
      case 'picked_up':
      case 'on_delivery':
        return _onDelivery;
      case 'delivered':
      case 'completed':
      case 'verified':
        return _delivered;
      case 'cancelled':
      case 'rejected':
        return _cancelled;
      default:
        return _pending;
    }
  }
}

/// Pill badge used across the rider screens.
class RiderStatusBadge extends StatelessWidget {
  const RiderStatusBadge({
    super.key,
    required this.label,
    required this.style,
    this.fontSize = 10,
  });

  final String label;
  final RiderStatusStyle style;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: style.foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: style.foreground,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// 10px uppercase DM Sans eyebrow, matching the site's section labels.
class RiderEyebrow extends StatelessWidget {
  const RiderEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.dustyRose,
        letterSpacing: 2,
      ),
    );
  }
}

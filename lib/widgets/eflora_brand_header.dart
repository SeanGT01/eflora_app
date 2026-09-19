import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Top brand header used across HomeScreen, SearchScreen, CartScreen, OrdersScreen, and AccountScreen.
/// Displays the custom SVG-matched flower painter and official E-FLORA brand typography.
class EfloraBrandHeader extends StatelessWidget {
  final double logoSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final Color? titleColor;
  final Color? subtitleColor;

  const EfloraBrandHeader({
    super.key,
    this.logoSize = 38,
    this.titleFontSize = 18,
    this.subtitleFontSize = 7,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flower logo (matching web SVG)
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: CustomPaint(
            painter: FlowerLogoPainter(),
          ),
        ),
        const SizedBox(width: 5),
        // Logo text
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'E-FLORA',
              style: GoogleFonts.cormorantGaramond(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: titleColor ?? AppColors.charcoal,
                height: 1.0,
              ),
            ),
            Text(
              'Blooming with Technology',
              style: GoogleFonts.dmSans(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w600,
                color: subtitleColor ?? AppColors.muted,
                letterSpacing: 0.18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Standardized top brand bar used across all 5 main screens (Home, Search, Cart, Orders, Account).
/// Guarantees identical pixel-perfect positioning, height, padding, and alignment of the logo & tagline.
class EfloraTopBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackground;
  final EdgeInsetsGeometry padding;

  const EfloraTopBar({
    super.key,
    this.actions,
    this.leading,
    this.showBackground = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56.0,
        padding: padding,
        decoration: showBackground
            ? const BoxDecoration(
                color: Color(0xF5FFFAFC),
                border: Border(
                  bottom: BorderSide(color: Color(0x8CFFFFFF), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0FB5445A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            const EfloraBrandHeader(),
            const Spacer(),
            if (actions != null && actions!.isNotEmpty) ...actions!,
          ],
        ),
      ),
    );
  }
}

/// Custom painter for E-FLORA flower logo (matching web SVG design)
class FlowerLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dustyRose = AppColors.dustyRose;
    const blush = AppColors.blush;

    // Draw 6 petals (ellipses rotated around center)
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * 3.14159 / 180; // Convert to radians
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // Draw petal (ellipse: width=5, height=8, positioned at top)
      final paint = Paint()
        ..color = (i % 2 == 0 ? dustyRose : blush)
            .withValues(alpha: (0.75 - i * 0.05).clamp(0.5, 1.0));

      // Ellipse positioned above center
      final petalRect = Rect.fromCenter(
        center: const Offset(0, -6),
        width: 5,
        height: 8,
      );
      canvas.drawOval(petalRect, paint);
      canvas.restore();
    }

    // Center circle (dusty rose)
    canvas.drawCircle(
      center,
      4,
      Paint()..color = dustyRose.withValues(alpha: 0.9),
    );

    // Inner white circle
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = const Color(0xFFFFFDF9),
    );

    // Gold center dot
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = const Color(0xFFffd700).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(FlowerLogoPainter oldDelegate) => false;
}

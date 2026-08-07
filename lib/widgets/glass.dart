import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_quality.dart';
import '../theme/app_theme.dart';

/// Frosted card matching the website's `.product-card` / `.profile-card`
/// recipe: translucent white fill, hairline highlight border, soft plum shadow
/// and a real backdrop blur (skipped on low-end / lite quality).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = AppRadius.lg,
    this.blur = 14,
    this.fill,
    this.borderColor,
    this.shadows,
    this.tinted = false,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final Color? fill;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  /// Adds the pink/lavender corner washes used on order cards.
  final bool tinted;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final useBlur = AppQuality.instance.useBlur && blur > 0;
    // Slightly more opaque fill when blur is off so cards stay readable
    final effectiveFill = fill ??
        (useBlur ? AppColors.glassFill : const Color(0xF5FFFFFF));
    final effectiveShadows = shadows ??
        (AppQuality.instance.useHeavyShadows
            ? AppShadows.glass
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A502846),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? AppColors.glassBorder, width: 1),
      ),
      child: Stack(
        children: [
          if (tinted && AppQuality.instance.isRich) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: const RadialGradient(
                    center: Alignment(-1, -1),
                    radius: 1.1,
                    colors: [Color(0x38FFBED2), Color(0x00FFBED2)],
                    stops: [0.0, 0.55],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: const RadialGradient(
                    center: Alignment(1, 1),
                    radius: 1.0,
                    colors: [Color(0x33D2BEF0), Color(0x00D2BEF0)],
                    stops: [0.0, 0.5],
                  ),
                ),
              ),
            ),
          ],
          // Top highlight, standing in for the CSS inset highlight.
          Positioned(
            top: 0,
            left: radius / 2,
            right: radius / 2,
            child: Container(height: 1, color: AppColors.glassHighlight),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.roseCta.withOpacity(0.06),
          highlightColor: AppColors.roseCta.withOpacity(0.04),
          child: content,
        ),
      );
    }

    Widget clipped = ClipRRect(
      borderRadius: borderRadius,
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: clipped,
    );
  }
}

/// Pill / rounded button filled with the signature pink → purple gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 50,
    this.radius = AppRadius.pill,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        width: expand ? double.infinity : null,
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled ? AppShadows.roseButton : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: textStyle ??
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular gradient action, e.g. the product card's add-to-cart button.
class GradientCircleButton extends StatelessWidget {
  const GradientCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.35)),
        boxShadow: const [
          BoxShadow(color: Color(0x40B5445A), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}

/// Section eyebrow + serif title, matching the site's section headers.
class GlassSectionTitle extends StatelessWidget {
  const GlassSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.dustyRose,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(title, style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

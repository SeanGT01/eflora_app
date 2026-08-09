
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

// Section header with eyebrow + title (matches web design)
class SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key, required this.eyebrow, required this.title,
    this.subtitle, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.dustyRose, letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// Category chip (pill)
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.glassBorder,
            width: 1.5,
          ),
          boxShadow: selected ? AppShadows.roseButton : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

// Shimmer loading card
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF6E7EE),
      highlightColor: AppColors.pageCream,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120, color: Colors.white, margin: const EdgeInsets.only(bottom: 4)),
                  Container(height: 10, width: 80, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
                  Container(height: 14, width: 60, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Rose action button
class RoseButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double? width;
  final ButtonStyle? style;

  const RoseButton({
    super.key, required this.label, this.onPressed,
    this.loading = false, this.icon, this.width, this.style,
  });

  @override
  Widget build(BuildContext context) {
    // Without a caller override, use the site's pink → purple gradient pill.
    if (style == null) {
      return SizedBox(
        width: width,
        child: GradientButton(
          label: label,
          icon: icon,
          loading: loading,
          onPressed: onPressed,
          expand: width != null,
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// Toast helper
void showToast(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.charcoal,
      margin: const EdgeInsets.all(16),
    ),
  );
}

/// Friendly modal when outbound verification email / Gmail auth fails.
Future<void> showEmailServiceUnavailableDialog(BuildContext context) {
  const supportEmail = 'support@eflora.ph';
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.deepRose.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                color: AppColors.deepRose,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Verification email unavailable',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "We couldn't send your verification code right now. "
              'This is a temporary issue on our side — your details are fine.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact the developer or support team, then try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.deepRose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                supportEmail,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRose,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Got it',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

bool isEmailServiceUnavailableError(String? message, {String? errorCode}) {
  if (errorCode == 'email_service_unavailable' ||
      errorCode == 'sms_service_unavailable') {
    return true;
  }
  final m = (message ?? '').toLowerCase();
  return (m.contains('verification email') && m.contains('unavailable')) ||
      m.contains("couldn't send your verification email") ||
      m.contains("couldn't send your verification sms") ||
      m.contains('sms_service_unavailable');
}

bool isSmsServiceUnavailableError(String? message, {String? errorCode}) {
  if (errorCode == 'sms_service_unavailable') return true;
  final m = (message ?? '').toLowerCase();
  return m.contains('verification sms') ||
      m.contains("couldn't send your verification sms");
}

// Divider with label
class LabeledDivider extends StatelessWidget {
  final String label;
  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      const Expanded(child: Divider()),
    ]);
  }
}

// Status badge
class StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const StatusBadge({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

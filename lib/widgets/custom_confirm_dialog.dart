import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? contentWidget;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final bool isDestructive;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isConfirmEnabled;
  final bool showCancelButton;

  const CustomConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.contentWidget,
    required this.confirmText,
    required this.cancelText,
    required this.onConfirm,
    required this.onCancel,
    this.icon,
    this.isDestructive = false,
    this.isConfirmEnabled = true,
    this.showCancelButton = true,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    Widget? contentWidget,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    bool isDestructive = false,
    bool showCancelButton = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomConfirmDialog(
        title: title,
        message: message,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        isDestructive: isDestructive,
        showCancelButton: showCancelButton,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
      ),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.35))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? const Color(0xFFFDE8E8)
                          : AppColors.blush.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon ?? (isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
                      color: isDestructive ? const Color(0xFFD32F2F) : AppColors.deepRose,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCancel,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                children: [
                  if (contentWidget != null)
                    contentWidget!
                  else if (message != null)
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.charcoal.withValues(alpha: 0.8),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (showCancelButton) ...[
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F2EE),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onCancel,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: Center(
                                  child: Text(
                                    cancelText,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: isConfirmEnabled
                              ? (isDestructive
                                  ? BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                                      ),
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x38E53935),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    )
                                  : BoxDecoration(
                                      gradient: AppColors.brandGradient,
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      boxShadow: AppShadows.roseButton,
                                    ))
                              : BoxDecoration(
                                  color: const Color(0xFFE2DDD8),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isConfirmEnabled ? onConfirm : null,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: Center(
                                child: Text(
                                  confirmText,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isConfirmEnabled ? Colors.white : const Color(0xFF9E9E9E),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

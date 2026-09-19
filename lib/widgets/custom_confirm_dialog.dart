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
      barrierColor: Colors.black.withValues(alpha: 0.45),
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
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      elevation: 8,
      shadowColor: const Color(0x1F502846),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with Icon + Title + Close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.dustyRose.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon ??
                          (isDestructive
                              ? Icons.warning_amber_rounded
                              : Icons.help_outline_rounded),
                      color: isDestructive
                          ? AppColors.deepRose
                          : AppColors.deepRose,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal.withValues(alpha: 0.05),
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
              const SizedBox(height: 16),

              // Body content
              if (contentWidget != null)
                contentWidget!
              else if (message != null)
                Text(
                  message!,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.charcoal.withValues(alpha: 0.85),
                  ),
                ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  if (showCancelButton) ...[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.borderStrong),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          child: Text(
                            cancelText,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: isConfirmEnabled
                          ? (isDestructive
                              ? BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFB5445A),
                                      Color(0xFF8B263E),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x38B5445A),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                )
                              : BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  boxShadow: AppShadows.roseButton,
                                ))
                          : BoxDecoration(
                              color:
                                  AppColors.borderStrong.withValues(alpha: 0.4),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isConfirmEnabled
                                    ? Colors.white
                                    : AppColors.muted,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

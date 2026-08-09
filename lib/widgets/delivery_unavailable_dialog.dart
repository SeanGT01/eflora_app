import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// True when an API/cart error is about store delivery coverage.
bool isDeliveryUnavailableError(String? message) {
  if (message == null || message.trim().isEmpty) return false;
  final m = message.toLowerCase();
  return m.contains("can't deliver") ||
      m.contains('cannot deliver') ||
      m.contains('cannot be delivered') ||
      m.contains('does not deliver') ||
      (m.contains('outside') &&
          (m.contains('delivery') ||
              m.contains('distance') ||
              m.contains('radius') ||
              m.contains('area'))) ||
      m.contains('delivery distance') ||
      m.contains('delivery radius') ||
      m.contains('delivery area') ||
      m.contains('delivery coverage') ||
      m.contains('maximum delivery') ||
      m.contains('missing map coordinates') ||
      m.contains('undeliverable');
}

String _humanizeDeliveryReason(String? reason) {
  final raw = (reason ?? '').trim();
  final lower = raw.toLowerCase();
  if (raw.isEmpty ||
      lower.contains('outside delivery distance') ||
      lower.contains('outside delivery area')) {
    return 'This shop can’t deliver to your saved address — it’s outside their delivery coverage.';
  }
  return raw;
}

/// Shows a friendly dialog instead of dumping the raw API error string.
Future<void> showDeliveryUnavailableDialog(
  BuildContext context, {
  String? reason,
  String title = 'Outside delivery area',
  List<String>? storeDetails,
  String? tip,
}) {
  final detail = _humanizeDeliveryReason(reason);

  final tipText = tip ??
      'You can still browse this shop, but checkout needs an address inside their delivery coverage — or turn on “Browse outside location” only for browsing.';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.dustyRose.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              color: AppColors.deepRose,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.charcoal.withValues(alpha: 0.85),
              ),
            ),
            if (storeDetails != null && storeDetails.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...storeDetails.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: AppColors.dustyRose.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.charcoal.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              tipText,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            'Got it',
            style: GoogleFonts.dmSans(
              color: AppColors.deepRose,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Checkout-specific delivery failure (selected items outside coverage).
Future<void> showCheckoutDeliveryUnavailableDialog(
  BuildContext context, {
  String? reason,
  List<String>? storeDetails,
}) {
  return showDeliveryUnavailableDialog(
    context,
    title: 'Cannot deliver here',
    reason: (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Some selected items cannot be delivered to this address.',
    storeDetails: storeDetails,
    tip:
        'Deselect those items, or choose a different delivery address that falls within each shop’s coverage area.',
  );
}

/// Routes cart/action failures: delivery coverage → dialog, otherwise toast.
void showCartActionError(BuildContext context, String error) {
  if (isDeliveryUnavailableError(error)) {
    showDeliveryUnavailableDialog(context, reason: error);
  } else {
    showToast(context, error, isError: true);
  }
}

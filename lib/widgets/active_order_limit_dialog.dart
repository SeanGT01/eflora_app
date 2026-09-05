import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/checkout.dart';
import '../screens/orders/orders_screen.dart';
import '../theme/app_theme.dart';

bool isActiveOrderLimitError(String? message, {String? code}) {
  if (code == 'active_order_limit') return true;
  final m = (message ?? '').toLowerCase();
  return m.contains('active order') &&
      (m.contains('maximum') || m.contains('already have'));
}

bool isActiveOrderLimitResult({String? message, Object? data}) {
  if (data is CheckoutValidationResponse) {
    return isActiveOrderLimitError(data.error ?? message, code: data.code);
  }
  if (data is Map && data['code']?.toString() == 'active_order_limit') {
    return true;
  }
  return isActiveOrderLimitError(message);
}

Future<void> showActiveOrderLimitDialog(
  BuildContext context, {
  int count = 5,
  int limit = 5,
}) {
  final safeLimit = limit < 1 ? 5 : limit;
  final filled = count.clamp(0, safeLimit);

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
              Icons.shopping_bag_outlined,
              color: AppColors.deepRose,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Order limit reached',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You already have $safeLimit active orders — the most you can have at once.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.45,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(safeLimit, (i) {
              final on = i < filled;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: on ? AppColors.deepRose : AppColors.cream,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            'Go to My Orders and mark a delivered order as Completed. Then you can place a new one.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            'Got it',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.deepRose,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            );
          },
          child: Text(
            'View my orders',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Future<bool> maybeShowActiveOrderLimitDialog(
  BuildContext context, {
  String? message,
  Object? data,
}) async {
  if (!isActiveOrderLimitResult(message: message, data: data)) return false;
  await showActiveOrderLimitDialogFromPayload(context, data: data);
  return true;
}

Future<void> showActiveOrderLimitDialogFromPayload(
  BuildContext context, {
  Object? data,
}) {
  var count = 5;
  var limit = 5;
  if (data is CheckoutValidationResponse) {
    count = data.activeOrderCount ?? 5;
    limit = data.orderLimit ?? 5;
  } else if (data is Map) {
    count = (data['active_order_count'] as num?)?.toInt() ?? 5;
    limit = (data['limit'] as num?)?.toInt() ?? 5;
  }
  return showActiveOrderLimitDialog(context, count: count, limit: limit);
}

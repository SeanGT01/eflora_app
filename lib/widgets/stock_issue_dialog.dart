import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class StockIssue {
  final String name;
  final int requested;
  final int available;
  final String code;
  final String message;
  final String? imageUrl;

  const StockIssue({
    required this.name,
    required this.requested,
    required this.available,
    required this.code,
    required this.message,
    this.imageUrl,
  });

  factory StockIssue.fromJson(Map<String, dynamic> j) {
    return StockIssue(
      name: j['name']?.toString() ?? 'Item',
      requested: j['requested'] is int
          ? j['requested'] as int
          : int.tryParse('${j['requested']}') ?? 0,
      available: j['available'] is int
          ? j['available'] as int
          : int.tryParse('${j['available']}') ?? 0,
      code: j['code']?.toString() ?? 'insufficient',
      message: j['message']?.toString() ?? 'Item is unavailable',
      imageUrl: j['image_url']?.toString(),
    );
  }
}

Future<void> showStockIssueDialog(
  BuildContext context, {
  required List<StockIssue> issues,
  String title = 'Stock unavailable',
  String? intro,
}) {
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
              Icons.inventory_2_outlined,
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
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intro ??
                    'Some items in your selection can’t be checked out right now. Update your basket quantities, then try again.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.charcoal.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              ...issues.map((issue) => _StockIssueTile(issue: issue)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            'Close',
            style: GoogleFonts.dmSans(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            'Review basket',
            style: GoogleFonts.dmSans(
              color: AppColors.deepRose,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StockIssueTile extends StatelessWidget {
  final StockIssue issue;
  const _StockIssueTile({required this.issue});

  @override
  Widget build(BuildContext context) {
    final out = issue.available <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFF5EDE6),
              child: issue.imageUrl != null && issue.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: issue.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.local_florist_outlined,
                        color: AppColors.muted,
                        size: 20,
                      ),
                    )
                  : const Icon(
                      Icons.local_florist_outlined,
                      color: AppColors.muted,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        issue.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: out
                            ? AppColors.error.withValues(alpha: 0.12)
                            : const Color(0xFFF0B429).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        out ? 'Out of stock' : 'Only ${issue.available} left',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: out
                              ? const Color(0xFF9B1C1C)
                              : const Color(0xFF8A5A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  issue.message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
                if (issue.requested > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Requested: ${issue.requested} · Available: ${issue.available}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';

/// Compact Material 3 card — not a nested chat bubble.
class ChatOrderCardMessage extends StatelessWidget {
  final ChatOrderContext ctx;
  final bool isSent;

  const ChatOrderCardMessage({
    super.key,
    required this.ctx,
    required this.isSent,
  });

  String _peso(double n) => '₱${n.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final items = ctx.items.take(4).toList();
    final extra = (ctx.itemCount - items.length).clamp(0, 99);
    const radius = 12.0;

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.orderNumber,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.15,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map((item) {
              final title = [item.name, item.variantName]
                  .where((s) => s != null && s.toString().trim().isNotEmpty)
                  .join(' · ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _ph(),
                            )
                          : _ph(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'Product' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.charcoal,
                            ),
                          ),
                          ...item.addons.map((a) {
                            final name = (a['name'] ?? a['addon_name'] ?? 'Add-on')
                                .toString();
                            final qRaw = a['quantity'];
                            final qty = qRaw is int
                                ? qRaw
                                : int.tryParse('${qRaw ?? 1}') ?? 1;
                            final label = qty > 1 ? '+ $name ×$qty' : '+ $name';
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: AppColors.muted,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '×${item.quantity}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '+$extra more',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ),
            Row(
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  _peso(ctx.totalAmount),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFFF3EDF7),
      child: const Icon(Icons.local_florist_outlined,
          size: 16, color: AppColors.deepRose),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';

/// Compact order summary shown under the chat header for rider↔customer threads.
/// Tappable expand when the order has 2+ items.
class ChatOrderContextBanner extends StatefulWidget {
  final ChatOrderContext orderContext;

  const ChatOrderContextBanner({super.key, required this.orderContext});

  @override
  State<ChatOrderContextBanner> createState() => _ChatOrderContextBannerState();
}

class _ChatOrderContextBannerState extends State<ChatOrderContextBanner> {
  bool _expanded = false;

  String _peso(double n) => '₱${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)}';

  String _itemTitle(ChatOrderItem item) => [
        item.name,
        if (item.variantName != null && item.variantName!.isNotEmpty) item.variantName!,
      ].join(' · ');

  double _chatItemLineTotal(ChatOrderItem item) {
    if (item.total > 0) return item.total;
    final addonsSum = item.addons.fold<double>(0, (s, a) {
      final price = (a['price'] as num?)?.toDouble() ?? 0;
      final qty = (a['quantity'] as num?)?.toInt() ?? 1;
      final total = (a['total'] as num?)?.toDouble();
      return s + (total ?? price * (qty <= 0 ? 1 : qty));
    });
    return (item.price * item.quantity) + addonsSum;
  }

  @override
  void didUpdateWidget(covariant ChatOrderContextBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderContext.orderId != widget.orderContext.orderId) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.orderContext;
    final items = order.items;
    final primary = items.isNotEmpty ? items.first : null;
    final canExpand = items.length >= 2 || order.itemCount >= 2;
    final extraCount = (order.itemCount - 1).clamp(0, 99);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.9), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _thumb(primary?.imageUrl, size: 52),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  order.orderNumber,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepRose,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.deepRose.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.statusLabel,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.deepRose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            primary == null
                                ? (order.storeName ?? 'Order items')
                                : _itemTitle(primary),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (primary != null) 'Qty ${primary.quantity}',
                              if (canExpand && !_expanded && extraCount > 0) '+$extraCount more',
                              if (canExpand && _expanded) '${order.itemCount} items',
                              if (!canExpand &&
                                  order.storeName != null &&
                                  order.storeName!.isNotEmpty)
                                order.storeName!,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _peso(order.totalAmount),
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          'Total',
                          style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (canExpand) ...[
                      const SizedBox(width: 2),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 22,
                        color: AppColors.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _expandedList(order, items),
            crossFadeState: _expanded && canExpand
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _expandedList(ChatOrderContext order, List<ChatOrderItem> items) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.7), width: 0.5)),
        color: Colors.white.withOpacity(0.55),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Row(
            children: [
              _thumb(item.imageUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _itemTitle(item),
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty ${item.quantity} · ${_peso(item.price)} each',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                    ),
                    if (item.addons.isNotEmpty)
                      ...item.addons.map((a) {
                        final name = (a['name'] ?? 'Add-on').toString();
                        final q = (a['quantity'] as num?)?.toInt() ?? 1;
                        return Text(
                          '+ $name${q > 1 ? ' ×$q' : ''}',
                          style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _peso(_chatItemLineTotal(item)),
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumb(String? url, {double size = 52}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size >= 48 ? 10 : 8),
      child: Container(
        width: size,
        height: size,
        color: AppColors.blush.withOpacity(0.35),
        child: url == null || url.isEmpty
            ? Icon(Icons.local_florist_rounded, color: AppColors.deepRose.withOpacity(0.55), size: size * 0.45)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: SizedBox(
                    width: size * 0.3,
                    height: size * 0.3,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.deepRose.withOpacity(0.55),
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }
}

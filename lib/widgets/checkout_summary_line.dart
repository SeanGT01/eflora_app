import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cart.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';

CartItem? matchCheckoutCartItem({
  required List<CartItem> cartItems,
  required int? productId,
  required int? variantId,
}) {
  for (final ci in cartItems) {
    final sameProduct = ci.productId == (productId ?? -1);
    final sameVariant = (ci.variantId ?? -1) == (variantId ?? -1);
    if (sameProduct && sameVariant) return ci;
  }
  return null;
}

String resolveCheckoutItemName({
  required Map<String, dynamic> item,
  required List<CartItem> cartItems,
  required int? productId,
  required int? variantId,
}) {
  final apiName = (item['name'] ?? '').toString().trim();
  if (apiName.isNotEmpty && !apiName.startsWith('Product #')) return apiName;

  final match = matchCheckoutCartItem(
    cartItems: cartItems,
    productId: productId,
    variantId: variantId,
  );
  if (match != null && match.name.trim().isNotEmpty) return match.name;

  if (productId != null && variantId != null) {
    return 'Product #$productId (Variant #$variantId)';
  }
  if (productId != null) return 'Product #$productId';
  return 'Checkout item';
}

String? resolveCheckoutItemImage({
  required Map<String, dynamic> item,
  CartItem? cartItem,
}) {
  if (cartItem != null) {
    final opt = cartItem.optimizedImageUrl;
    if (opt != null && opt.isNotEmpty) return opt;
    final fromCart = _optimizeRawImage(cartItem.imageUrl ?? '');
    if (fromCart != null) return fromCart;
    final primary = _optimizeRawImage(cartItem.product.primaryImageUrl ?? '');
    if (primary != null) return primary;
  }
  return _optimizeRawImage((item['image_url'] ?? '').toString().trim());
}

String? _optimizeRawImage(String raw) {
  if (raw.isEmpty) return null;
  if (raw.contains('cloudinary_e-flowers/')) {
    final withoutExt = raw.replaceFirst('cloudinary_', '').split('.').first;
    return 'https://res.cloudinary.com/${CloudinaryService.cloudName}/image/upload/w_160,h_160,c_fill,q_auto,f_auto/$withoutExt';
  }
  if (raw.contains('cloudinary.com')) {
    return CloudinaryService.getThumbnailUrl(raw, size: 160);
  }
  if (raw.startsWith('http')) return raw;
  return null;
}

/// Compact product row used on checkout review and payment summaries.
class CheckoutSummaryLine extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final double? origPrice;
  final int? discountPct;
  final List<Map<String, dynamic>> addons;

  const CheckoutSummaryLine({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.origPrice,
    this.discountPct,
    this.addons = const [],
  });

  factory CheckoutSummaryLine.fromCheckoutItem({
    Key? key,
    required Map<String, dynamic> item,
    required List<CartItem> cartItems,
  }) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final origPrice = (item['original_price'] as num?)?.toDouble();
    final discPct = (item['discount_pct'] as num?)?.toInt();
    final productId = (item['product_id'] as num?)?.toInt();
    final variantId = (item['variant_id'] as num?)?.toInt();
    var addons = (item['addons'] as List?) ?? const [];
    var addonsTotal = (item['addons_total'] as num?)?.toDouble() ??
        addons.fold<double>(0, (s, raw) {
          final a = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
          final aQty = (a['quantity'] as num?)?.toInt() ??
              (a['units'] as num?)?.toInt() ??
              1;
          final aTotal = (a['total'] as num?)?.toDouble();
          return s + (aTotal ?? aPrice * (aQty <= 0 ? 1 : aQty));
        });

    final match = matchCheckoutCartItem(
      cartItems: cartItems,
      productId: productId,
      variantId: variantId,
    );
    if ((addons.isEmpty || addonsTotal <= 0) &&
        match != null &&
        (match.addons.isNotEmpty || match.addonsTotal > 0)) {
      addons = match.addons
          .map((a) => {
                'name': a.name,
                'price': a.price,
                'quantity': a.quantity,
                'image_url': a.imageUrl,
                'group_name': a.groupName,
              })
          .toList();
      addonsTotal = match.addonsUnitTotal;
    }

    final addonMaps = addons
        .map((raw) => raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map))
        .toList();

    return CheckoutSummaryLine(
      key: key,
      name: resolveCheckoutItemName(
        item: item,
        cartItems: cartItems,
        productId: productId,
        variantId: variantId,
      ),
      imageUrl: resolveCheckoutItemImage(item: item, cartItem: match),
      qty: qty,
      unitPrice: unitPrice,
      lineTotal: (unitPrice * qty) + addonsTotal,
      origPrice: origPrice,
      discountPct: discPct,
      addons: addonMaps,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x66F5EDE6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Qty $qty  ·  ₱${unitPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (origPrice != null)
                        Text(
                          '₱${origPrice!.toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (discountPct != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: AppColors.badgeGradient,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$discountPct% off',
                            style: GoogleFonts.dmSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  ...addons.map(_addonRow),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₱${lineTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addonRow(Map<String, dynamic> a) {
    final aName = (a['name'] ?? 'Add-on').toString();
    final aGroup = (a['group_name'] ?? '').toString();
    final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
    final aImg = _optimizeRawImage((a['image_url'] ?? '').toString().trim());
    final label = aGroup.isNotEmpty ? '$aGroup: $aName' : aName;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (aImg != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: aImg,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                memCacheWidth: 40,
                memCacheHeight: 40,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              '+ $label',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '₱${aPrice.toStringAsFixed(2)}',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;

  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: AppColors.pageCream,
        child: url == null || url!.isEmpty
            ? const _FloristFallback()
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.contain,
                memCacheWidth: 160,
                memCacheHeight: 160,
                placeholder: (_, __) => Container(
                  decoration: const BoxDecoration(gradient: AppColors.imageWash),
                ),
                errorWidget: (_, __, ___) => const _FloristFallback(),
              ),
      ),
    );
  }
}

class _FloristFallback extends StatelessWidget {
  const _FloristFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: const Center(
        child: Icon(Icons.local_florist, color: AppColors.roseCta, size: 22),
      ),
    );
  }
}

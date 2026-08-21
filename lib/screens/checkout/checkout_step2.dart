import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/checkout.dart';
import '../../models/cart.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

// Amber info/warning callout tokens, matching the website's notice styling.
const Color _amberBg = Color(0xFFFFF1DE);
const Color _amberBorder = Color(0xFFF0C98B);
const Color _amberText = Color(0xFF9A5B00);

class CheckoutStep2 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const CheckoutStep2({
    super.key,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<CheckoutStep2> createState() => _CheckoutStep2State();
}

class _CheckoutStep2State extends State<CheckoutStep2> {
  late CheckoutValidationResponse _validationResponse;

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, checkoutProvider, _) {
        if (checkoutProvider.validationResponse == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.roseCta),
          );
        }

        _validationResponse = checkoutProvider.validationResponse!;
        final cartItems = context.watch<CartProvider>().items;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepHeader(context),
                const SizedBox(height: 24),
                _buildDeliverySummary(context, checkoutProvider),
                const SizedBox(height: 24),
                const SectionHeader(
                  eyebrow: 'Review',
                  title: 'Order Breakdown',
                  subtitle: 'Check delivery fees, store totals, and payment details.',
                ),
                const SizedBox(height: 16),
                ..._validationResponse.storeOrderTotals.asMap().entries.map((entry) {
                  return _buildStoreOrderCard(
                    context,
                    entry.value,
                    entry.key + 1,
                    cartItems,
                  );
                }),
                const SizedBox(height: 24),
                _buildGrandTotalSection(context, cartItems),
                const SizedBox(height: 24),
                if (_validationResponse.warnings != null &&
                    _validationResponse.warnings!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      border: Border.all(color: _amberBorder),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important notices',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: _amberText,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ..._validationResponse.warnings!.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '- $warning',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _amberText,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onPrevious,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: 'Upload Payment Proof',
                        onPressed: widget.onNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliverySummary(BuildContext context, CheckoutProvider provider) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery summary', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.roseCta, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.selectedAddress?.addressLine ?? 'No delivery address selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: AppColors.muted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You will choose delivery date & time for each store in the next step.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreOrderCard(
    BuildContext context,
    StoreOrderTotal storeOrder,
    int index,
    List<CartItem> cartItems,
  ) {
    final displaySubtotal = _storeSubtotalIncludingAddons(storeOrder, cartItems);
    final displayTotal = displaySubtotal + storeOrder.deliveryFee;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glass,
      ),
      child: ExpansionTile(
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        iconColor: AppColors.roseCta,
        collapsedIconColor: AppColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store $index: ${storeOrder.storeName}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPink,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (!storeOrder.canDeliver && storeOrder.deliveryError != null)
                    Text(
                      'Outside delivery area',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${storeOrder.distanceKm.toStringAsFixed(1)} km away',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (storeOrder.canDeliver)
              Text(
                '₱${storeOrder.total.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepRose,
                ),
              )
            else
              const Icon(Icons.error_outline, color: Color(0xFFc0392b), size: 20),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (storeOrder.items != null && storeOrder.items!.isNotEmpty) ...[
                  Text('Items', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...storeOrder.items!.map((item) {
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    final unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final origPrice = (item['original_price'] as num?)?.toDouble();
                    final discPct = item['discount_pct'] as int?;
                    final productId = item['product_id'] as int?;
                    final variantId = item['variant_id'] as int?;
                    final addons = (item['addons'] as List?) ?? const [];
                    final addonsTotal = (item['addons_total'] as num?)?.toDouble() ??
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
                    // Prefer cart line add-ons when validate payload omitted them.
                    var resolvedAddonsTotal = addonsTotal;
                    var resolvedAddons = addons;
                    if ((addons.isEmpty || addonsTotal <= 0) &&
                        productId != null) {
                      CartItem? match;
                      for (final ci in cartItems) {
                        if (ci.productId == productId &&
                            ci.variantId == variantId) {
                          match = ci;
                          break;
                        }
                      }
                      if (match != null &&
                          (match.addons.isNotEmpty || match.addonsTotal > 0)) {
                        resolvedAddons = match.addons
                            .map((a) => {
                                  'name': a.name,
                                  'price': a.price,
                                  'quantity': a.quantity,
                                  'image_url': a.imageUrl,
                                  'group_name': a.groupName,
                                })
                            .toList();
                        resolvedAddonsTotal = match.addonsUnitTotal;
                      }
                    }
                    final lineTotal = (unitPrice * qty) + resolvedAddonsTotal;
                    final resolvedName = _resolveCheckoutItemName(
                      cartItems: cartItems,
                      productId: productId,
                      variantId: variantId,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resolvedName,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Qty: $qty x ₱${unitPrice.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (origPrice != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '₱${origPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                    if (discPct != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          gradient: AppColors.badgeGradient,
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                        ),
                                        child: Text(
                                          '$discPct% off',
                                          style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                ...resolvedAddons.map((raw) {
                                  final a = raw is Map<String, dynamic>
                                      ? raw
                                      : Map<String, dynamic>.from(raw as Map);
                                  final aName = (a['name'] ?? 'Add-on').toString();
                                  final aGroup = (a['group_name'] ?? '').toString();
                                  final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
                                  final aImg = (a['image_url'] ?? '').toString();
                                  final label = aGroup.isNotEmpty ? '$aGroup: $aName' : aName;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        if (aImg.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.network(
                                              aImg,
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                            ),
                                          ),
                                        if (aImg.isNotEmpty) const SizedBox(width: 5),
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
                                }),
                              ],
                            ),
                          ),
                          Text(
                            '₱${lineTotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                ],
                _buildPriceRow('Subtotal', displaySubtotal),
                const Divider(),
                _buildPriceRow(
                  'Delivery Fee',
                  storeOrder.deliveryFee,
                  isDeliveryFee: true,
                  isFree: storeOrder.canDeliver &&
                      (storeOrder.freeDeliveryApplied || storeOrder.deliveryFee <= 0),
                ),
                if (storeOrder.canDeliver) ..._deliveryFeeNotes(
                  storeOrder,
                  subtotalOverride: displaySubtotal,
                ),
                const Divider(),
                _buildPriceRow('Total', displayTotal, isBold: true, isTotal: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _deliveryFeeNotes(
    StoreOrderTotal storeOrder, {
    double? subtotalOverride,
  }) {
    final applied = storeOrder.freeDeliveryApplied ||
        (storeOrder.deliveryFee <= 0 && storeOrder.freeDeliveryEnabled);
    if (applied) {
      return [
        const SizedBox(height: 4),
        Text(
          'Your order qualifies for free delivery.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.successGreen,
          ),
        ),
      ];
    }

    if (!storeOrder.freeDeliveryEnabled) return const [];

    final subtotal = subtotalOverride ?? storeOrder.subtotal;
    final remaining = storeOrder.amountToFreeDelivery ??
        ((storeOrder.freeDeliveryMinimum ?? 0) - subtotal);
    if (remaining <= 0) return const [];

    final minLabel = (storeOrder.freeDeliveryMinimum ?? 0).toStringAsFixed(0);
    return [
      const SizedBox(height: 4),
      Text(
        'Add ₱${remaining.toStringAsFixed(2)} more to get free delivery (min ₱$minLabel).',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9A5B00),
        ),
      ),
    ];
  }

  double _storeSubtotalIncludingAddons(
    StoreOrderTotal storeOrder,
    List<CartItem> cartItems,
  ) {
    final items = storeOrder.items;
    if (items == null || items.isEmpty) {
      return storeOrder.subtotal;
    }

    var sum = 0.0;
    for (final item in items) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final unit = (item['price'] as num?)?.toDouble() ?? 0;
      final productId = item['product_id'] as int?;
      final variantId = item['variant_id'] as int?;
      final addons = (item['addons'] as List?) ?? const [];
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
      if ((addons.isEmpty || addonsTotal <= 0) && productId != null) {
        for (final ci in cartItems) {
          if (ci.productId == productId && ci.variantId == variantId) {
            if (ci.addons.isNotEmpty || ci.addonsTotal > 0) {
              addonsTotal = ci.addonsUnitTotal;
            }
            break;
          }
        }
      }
      sum += (unit * qty) + addonsTotal;
    }

    return sum > storeOrder.subtotal ? sum : storeOrder.subtotal;
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isTotal = false,
    bool isDeliveryFee = false,
    bool isFree = false,
  }) {
    final color = isFree
        ? AppColors.successGreen
        : isDeliveryFee
            ? const Color(0xFF9A5B00)
            : isTotal
                ? AppColors.deepRose
                : AppColors.charcoal;
    final amountText = isFree ? 'FREE' : '₱${amount.toStringAsFixed(2)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            fontSize: isBold ? 14 : 13,
            color: isBold ? AppColors.charcoal : AppColors.muted,
          ),
        ),
        isTotal
            ? Text(
                amountText,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              )
            : Text(
                amountText,
                style: GoogleFonts.dmSans(
                  fontWeight: isBold || isFree ? FontWeight.w700 : FontWeight.w600,
                  fontSize: isBold ? 14 : 13,
                  color: color,
                ),
              ),
      ],
    );
  }

  Widget _buildGrandTotalSection(BuildContext context, List<CartItem> cartItems) {
    final grand = _validationResponse.storeOrderTotals.fold<double>(0, (s, st) {
      final sub = _storeSubtotalIncludingAddons(st, cartItems);
      return s + sub + st.deliveryFee;
    });
    final displayGrand =
        grand > _validationResponse.grandTotal ? grand : _validationResponse.grandTotal;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.xl,
      borderColor: AppColors.roseCta.withOpacity(0.35),
      shadows: AppShadows.glassRaised,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Grand Total', style: Theme.of(context).textTheme.titleMedium),
          Text(
            '₱${displayGrand.toStringAsFixed(2)}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.deepRose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.xl,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.roseButton,
            ),
            child: Center(
              child: Text(
                '2',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP 2 OF 3',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.dustyRose,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 2),
                Text('Review your order', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Confirm delivery details and total charges before payment.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveCheckoutItemName({
    required List<CartItem> cartItems,
    required int? productId,
    required int? variantId,
  }) {
    for (final ci in cartItems) {
      final sameProduct = ci.productId == (productId ?? -1);
      final sameVariant = (ci.variantId ?? -1) == (variantId ?? -1);
      if (sameProduct && sameVariant) return ci.name;
    }
    if (productId != null && variantId != null) return 'Product #$productId (Variant #$variantId)';
    if (productId != null) return 'Product #$productId';
    return 'Checkout item';
  }
}

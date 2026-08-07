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
                _buildGrandTotalSection(context),
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
                    final lineTotal = unitPrice * qty;
                    final productId = item['product_id'] as int?;
                    final variantId = item['variant_id'] as int?;
                    final resolvedName = _resolveCheckoutItemName(
                      cartItems: cartItems,
                      productId: productId,
                      variantId: variantId,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
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
                _buildPriceRow('Subtotal', storeOrder.subtotal),
                const Divider(),
                _buildPriceRow('Delivery Fee', storeOrder.deliveryFee, isDeliveryFee: true),
                const Divider(),
                _buildPriceRow('Total', storeOrder.total, isBold: true, isTotal: true),
                const SizedBox(height: 12),
                if (storeOrder.qrImages != null && storeOrder.qrImages!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GCash QR Code', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          border: Border.all(color: AppColors.glassBorder, width: 1.5),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Image.network(storeOrder.qrImages![0], fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                if (storeOrder.instructions != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      border: Border.all(color: _amberBorder),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Instructions',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: _amberText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          storeOrder.instructions!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: _amberText),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isTotal = false,
    bool isDeliveryFee = false,
  }) {
    final color = isDeliveryFee
        ? const Color(0xFF9A5B00)
        : isTotal
            ? AppColors.deepRose
            : AppColors.charcoal;

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
                '₱${amount.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              )
            : Text(
                '₱${amount.toStringAsFixed(2)}',
                style: GoogleFonts.dmSans(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: isBold ? 14 : 13,
                  color: color,
                ),
              ),
      ],
    );
  }

  Widget _buildGrandTotalSection(BuildContext context) {
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
            '₱${_validationResponse.grandTotal.toStringAsFixed(2)}',
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

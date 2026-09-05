import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/checkout.dart';
import '../../models/cart.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checkout_summary_line.dart';
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

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeliverySummary(context, checkoutProvider),
                    const SizedBox(height: 14),
                    ..._validationResponse.storeOrderTotals.asMap().entries.map((entry) {
                      return _buildStoreOrderCard(
                        context,
                        entry.value,
                        entry.key + 1,
                        cartItems,
                      );
                    }),
                    if (_validationResponse.warnings != null &&
                        _validationResponse.warnings!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: _amberBg,
                          border: Border.all(color: _amberBorder),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._validationResponse.warnings!.map(
                              (warning) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  warning,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _amberText,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.pageCream.withValues(alpha: 0.92),
                  border: const Border(
                    top: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₱${_displayGrandTotal(cartItems).toStringAsFixed(2)}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                            label: 'Continue',
                            onPressed: widget.onNext,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliverySummary(BuildContext context, CheckoutProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_rounded, color: AppColors.roseCta, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deliver to',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                provider.selectedAddress?.addressLine ?? 'No address selected',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeOrder.storeName,
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
                if (!storeOrder.canDeliver)
                  const Icon(Icons.error_outline, color: Color(0xFFc0392b), size: 20),
              ],
            ),
            const SizedBox(height: 10),
            if (storeOrder.items != null && storeOrder.items!.isNotEmpty)
              ...storeOrder.items!.map((item) {
                return CheckoutSummaryLine.fromCheckoutItem(
                  item: Map<String, dynamic>.from(item),
                  cartItems: cartItems,
                );
              }),
            const SizedBox(height: 4),
            _buildPriceRow('Subtotal', displaySubtotal),
            _buildPriceRow(
              'Delivery Fee',
              storeOrder.deliveryFee,
              isDeliveryFee: true,
              isFree: storeOrder.canDeliver &&
                  (storeOrder.freeDeliveryApplied || storeOrder.deliveryFee <= 0),
              infoMessage: storeOrder.canDeliver
                  ? _deliveryFeeInfo(storeOrder, displaySubtotal)
                  : null,
            ),
            const Divider(),
            _buildPriceRow('Total', displayTotal, isBold: true, isTotal: true),
          ],
        ),
      ),
    );
  }

  String? _deliveryFeeInfo(StoreOrderTotal storeOrder, double subtotal) {
    final applied = storeOrder.freeDeliveryApplied ||
        (storeOrder.deliveryFee <= 0 && storeOrder.freeDeliveryEnabled);
    if (applied) {
      return 'Your order qualifies for free delivery.';
    }
    if (!storeOrder.freeDeliveryEnabled) return null;
    final remaining = storeOrder.amountToFreeDelivery ??
        ((storeOrder.freeDeliveryMinimum ?? 0) - subtotal);
    if (remaining <= 0) return null;
    final minLabel = (storeOrder.freeDeliveryMinimum ?? 0).toStringAsFixed(2);
    return 'Add ₱${remaining.toStringAsFixed(2)} more to get free delivery (min ₱$minLabel).';
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isTotal = false,
    bool isDeliveryFee = false,
    bool isFree = false,
    String? infoMessage,
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            if (infoMessage != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showDeliveryInfo(infoMessage),
                borderRadius: BorderRadius.circular(99),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isFree ? AppColors.successGreen : const Color(0xFF9A5B00),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showDeliveryInfo(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.charcoal,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: AppColors.deepRose,
              ),
            ),
          ),
        ],
      ),
    );
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

  double _displayGrandTotal(List<CartItem> cartItems) {
    final grand = _validationResponse.storeOrderTotals.fold<double>(0, (s, st) {
      final sub = _storeSubtotalIncludingAddons(st, cartItems);
      return s + sub + st.deliveryFee;
    });
    return grand > _validationResponse.grandTotal ? grand : _validationResponse.grandTotal;
  }

}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/cart.dart';
import '../../models/checkout.dart';
import '../../providers/cart_provider.dart';
import '../../providers/address_provider.dart';
import '../../services/checkout_service.dart';
import '../../services/app_quality.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_blur.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/delivery_unavailable_dialog.dart';
import '../../widgets/stock_issue_dialog.dart';
import '../checkout/checkout_modal.dart';
import '../main_shell.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _checkingDelivery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().load();
      context.read<AddressProvider>().loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return AppBackground(
      flowerCount: 10,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'My Cart',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.charcoal,
              letterSpacing: 0.3,
            ),
          ),
          actions: [
            if (cart.items.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear Cart'),
                      content: const Text('Remove all items from your cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) cart.clear();
                },
                child: Text('Clear',
                    style: GoogleFonts.dmSans(
                        color: AppColors.muted, fontSize: 13)),
              ),
          ],
        ),
        body: cart.loading && cart.items.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.roseCta))
            : RefreshIndicator(
                color: AppColors.roseCta,
                onRefresh: () => cart.load(showLoading: false),
                child: cart.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.55,
                            child: _buildEmpty(context),
                          ),
                        ],
                      )
                    : _buildStoreGroupedList(context, cart),
              ),
        // When nested in MainShell (extendBody: true), lift the checkout bar
        // above the shell's bottom nav so it stays tappable.
        bottomNavigationBar: cart.items.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(bottom: _shellNavClearance(context)),
                child: _buildCheckoutBar(context, cart),
              )
            : null,
      ),
    );
  }

  /// Height of MainShell's bottom nav (62) + home-indicator inset.
  /// Returns only the safe-area inset when CartScreen is pushed as a route.
  double _shellNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final insideShell =
        context.findAncestorStateOfType<MainShellState>() != null;
    return insideShell ? 62 + bottomInset : bottomInset;
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 72, color: AppColors.dustyRose.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Your cart is empty',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 8),
          Text('Add some beautiful blooms!',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              final shellState =
                  context.findAncestorStateOfType<MainShellState>();
              if (shellState != null) {
                shellState.switchToTab(0);
                return;
              }

              // Cart can also be opened as a pushed page (e.g. from Account),
              // where no MainShell ancestor exists. In that case, reset to shell.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShell()),
                (_) => false,
              );
            },
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  // ── Store-grouped cart list ────────────────────────────────────────────────
  Widget _buildStoreGroupedList(BuildContext context, CartProvider cart) {
    final groups = cart.storeGroups;
    final sortedStoreIds = groups.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _shellNavClearance(context)),
      children: [
        ...sortedStoreIds.map((storeId) {
          final group = groups[storeId]!;
          return _StoreSection(
            key: ValueKey('store_$storeId'),
            group: group,
            cart: cart,
          );
        }),
        const SizedBox(height: 16),
        _buildOrderSummary(context, cart),
        // Extra space so the last card clears the floating checkout bar.
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context, CartProvider cart) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR BAG',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.dustyRose,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text('Order Summary',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _summRow(context, 'All Items (${cart.itemCount})',
              '₱${cart.total.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _summRow(context, 'Selected (${cart.selectedItemCount})',
              '₱${cart.selectedTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _summRow(context, 'Delivery Fee', 'Calculated at checkout'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Selected Subtotal',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                '₱${cart.selectedTotal.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartProvider cart) {
    final hasSelection = cart.hasSelection;

    return ClipRect(
      child: AdaptiveBlur(
        sigma: 18,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: AppQuality.instance.useBlur ? 0.85 : 0.96),
            border: const Border(top: BorderSide(color: AppColors.glassBorder)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECTED TOTAL',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dustyRose,
                          letterSpacing: 2,
                        ),
                      ),
                      if (cart.selectedItemCount > 0)
                        Text(
                          '${cart.selectedItemCount} item${cart.selectedItemCount > 1 ? 's' : ''} selected',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.muted),
                        ),
                    ],
                  ),
                  Text(
                    '₱${cart.selectedTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRose),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: hasSelection
                    ? 'Proceed to Checkout (${cart.selectedItemCount})'
                    : 'Select items to checkout',
                loading: _checkingDelivery,
                onPressed: hasSelection && !_checkingDelivery
                    ? () => _proceedToCheckout(context, cart)
                    : null,
                icon: Icons.arrow_forward,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _proceedToCheckout(
      BuildContext context, CartProvider cart) async {
    final selectedItems = cart.selectedItems;

    if (selectedItems.isEmpty) {
      showToast(context, 'Please select items to checkout');
      return;
    }

    setState(() => _checkingDelivery = true);

    // Pre-checkout stock check (aligned with website)
    final stockResult = await CheckoutService.validateStock(
      mode: 'cart',
      items: selectedItems
          .map((i) => {
                'item_id': i.id,
                'quantity': i.quantity,
              })
          .toList(),
    );
    if (!mounted) return;

    if (!stockResult.isSuccess) {
      setState(() => _checkingDelivery = false);
      final rawIssues = stockResult.data is Map
          ? (stockResult.data as Map)['stock_issues']
          : null;
      if (rawIssues is List && rawIssues.isNotEmpty) {
        await showStockIssueDialog(
          context,
          issues: rawIssues
              .whereType<Map>()
              .map((e) => StockIssue.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      } else {
        showToast(
          context,
          stockResult.errorMessage ??
              'Some selected items are unavailable or have insufficient stock.',
          isError: true,
        );
      }
      return;
    }

    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.addresses.isEmpty) {
      await addressProvider.loadAddresses();
    }
    if (!mounted) return;

    final address = addressProvider.selectedAddress ??
        (addressProvider.addresses.isEmpty
            ? null
            : addressProvider.addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => addressProvider.addresses.first,
              ));

    // No saved address yet — let checkout modal handle address selection.
    if (address?.id == null) {
      setState(() => _checkingDelivery = false);
      _openCheckoutModal(context, cart, selectedItems);
      return;
    }

    final result = await CheckoutService.validateCheckout(
      addressId: address!.id!,
      deliveryNotes: '',
      items: selectedItems
          .map((item) => {
                'item_id': item.id,
                'quantity': item.quantity,
              })
          .toList(),
    );
    if (!mounted) return;
    setState(() => _checkingDelivery = false);

    if (!result.isSuccess) {
      final failed = result.data is CheckoutValidationResponse
          ? result.data as CheckoutValidationResponse
          : null;
      final error = result.errorMessage ??
          failed?.error ??
          'Some selected items cannot be delivered to this address.';
      final warnings = failed?.warnings;

      if (isDeliveryUnavailableError(error) ||
          (warnings != null && warnings.isNotEmpty)) {
        await showCheckoutDeliveryUnavailableDialog(
          context,
          reason: error,
          storeDetails: warnings,
        );
        return;
      }

      showToast(context, error, isError: true);
      return;
    }

    _openCheckoutModal(context, cart, selectedItems);
  }

  void _openCheckoutModal(
    BuildContext context,
    CartProvider cart,
    List<CartItem> selectedItems,
  ) {
    final addresses = context.read<AddressProvider>().addresses;
    showCheckoutModal(
      context,
      addresses: addresses,
      selectedItems: selectedItems,
      onComplete: () {
        cart.load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
      },
    );
  }
}

// ── Store section with header checkbox ───────────────────────────────────────
class _StoreSection extends StatelessWidget {
  final StoreCartGroup group;
  final CartProvider cart;

  const _StoreSection({
    super.key,
    required this.group,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Store header with checkbox
          InkWell(
            onTap: () => cart.toggleStoreSelection(group.storeId),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg)),
                border: const Border(
                    bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: group.allSelected,
                      tristate: true,
                      onChanged: (_) =>
                          cart.toggleStoreSelection(group.storeId),
                      activeColor: AppColors.roseCta,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.storefront_outlined,
                      size: 18, color: AppColors.labelPink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.storeName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPink,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${group.items.length} item${group.items.length > 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          // Cart items for this store
          ...group.items.map((item) => _CartItemTile(
                key: ValueKey('${item.id}_${item.variantId}'),
                item: item,
                cart: cart,
              )),
          // Store subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Store Subtotal',
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  '₱${group.selectedSubtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: group.anySelected
                        ? AppColors.deepRose
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart item tile with checkbox and Cloudinary image ────────────────────────
class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _CartItemTile({
    super.key,
    required this.item,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: AppColors.glassBorder.withValues(alpha: 0.6),
                width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: item.isSelected,
              onChanged: (_) => cart.toggleItemSelection(item.id),
              activeColor: AppColors.roseCta,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _buildImage(),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        item.isSelected ? AppColors.charcoal : AppColors.muted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.isVariant)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.roseCta.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: AppColors.roseCta.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        'Variant: ${item.variant?.name ?? ''}',
                        style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepRose),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '₱${item.price.toStringAsFixed(2)} each',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    if (item.originalPrice != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '₱${item.originalPrice!.toStringAsFixed(2)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      if (item.discountPct != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: AppColors.badgeGradient,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${item.discountPct}% off',
                            style: GoogleFonts.dmSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _CartQtyControl(
                  qty: item.quantity,
                  onMinus: item.quantity > 1
                      ? () => cart.updateItem(item.id, item.quantity - 1)
                      : null,
                  onPlus: item.quantity < item.stockQuantity
                      ? () => cart.updateItem(item.id, item.quantity + 1)
                      : null,
                ),
              ],
            ),
          ),
          // Price + delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${item.subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: item.isSelected ? AppColors.deepRose : AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => cart.removeItem(item.id),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    border:
                        Border.all(color: AppColors.glassBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
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

  Widget _buildImage() {
    final imageUrl = item.optimizedImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return _buildPlaceholder();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: 150,
      memCacheHeight: 150,
      placeholder: (_, __) => Container(
        decoration: const BoxDecoration(gradient: AppColors.imageWash),
        child: const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.roseCta)),
        ),
      ),
      errorWidget: (_, url, error) {
        debugPrint('Failed to load cart image: $url - $error');
        if (item.product.images.isNotEmpty) {
          final fallbackUrl = item.product.primaryImageUrl;
          if (fallbackUrl != null) {
            return CachedNetworkImage(
              imageUrl: fallbackUrl,
              fit: BoxFit.cover,
              memCacheWidth: 150,
              memCacheHeight: 150,
              errorWidget: (_, __, ___) => _buildPlaceholder(),
            );
          }
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Icon(Icons.local_florist,
            size: 28, color: AppColors.deepRose.withValues(alpha: 0.16)),
      ),
    );
  }
}

class _CartQtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _CartQtyControl({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x73E6AAC3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CartQtyBtn(
            icon: Icons.remove,
            onTap: onMinus,
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x4DE6AAC3), width: 1.5),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
          _CartQtyBtn(
            icon: Icons.add,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _CartQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CartQtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 32,
          child: Icon(
            icon,
            size: 15,
            color: enabled ? AppColors.charcoal : AppColors.borderStrong,
          ),
        ),
      ),
    );
  }
}

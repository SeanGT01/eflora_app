import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/cart.dart';
import '../../models/checkout.dart';
import '../../providers/cart_provider.dart';
import '../../providers/address_provider.dart';
import '../../services/checkout_service.dart';
import '../../navigation/floating_nav_metrics.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_confirm_dialog.dart';
import '../../widgets/delivery_unavailable_dialog.dart';
import '../../widgets/active_order_limit_dialog.dart';
import '../../widgets/stock_issue_dialog.dart';
import '../checkout/checkout_modal.dart';
import '../main_shell.dart';
import '../orders/orders_screen.dart';

const _kDeepRose = Color(0xFFB5445A);
const _kDustyRose = Color(0xFFD4788A);
const _kSoftBlush = Color(0xFFFBE9EE);
const _kTextCharcoal = Color(0xFF2C2520);
const _kMuted = Color(0xFF8F7D79);
const _kBorder = Color(0xFFF0DDE2);

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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, cart),
              Expanded(
                child: cart.loading && cart.items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: _kDeepRose),
                      )
                    : RefreshIndicator(
                        color: _kDeepRose,
                        onRefresh: () => cart.load(showLoading: false),
                        child: cart.items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.sizeOf(context).height * 0.65,
                                    child: _buildEmpty(context),
                                  ),
                                ],
                              )
                            : _buildStoreGroupedList(context, cart),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: cart.items.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(bottom: _shellNavClearance(context)),
                child: _buildCheckoutBar(context, cart),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CartProvider cart) {
    return Column(
      children: [
        EfloraTopBar(
          actions: [
            if (cart.items.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: _kDustyRose,
                  size: 22,
                ),
                tooltip: 'Clear Cart',
                onPressed: () async {
                  final confirm = await CustomConfirmDialog.show(
                    context,
                    title: 'Clear Cart',
                    message: 'Remove all items from your cart?',
                    confirmText: 'Clear',
                    cancelText: 'Cancel',
                    icon: Icons.remove_shopping_cart_outlined,
                    isDestructive: true,
                  );
                  if (confirm == true) cart.clear();
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MY SHOPPING BAG',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _kDustyRose,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Review Selected Items',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _kTextCharcoal,
                    ),
                  ),
                ],
              ),
              if (cart.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kSoftBlush,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: _kBorder, width: 0.9),
                  ),
                  child: Text(
                    '${cart.itemCount} item${cart.itemCount != 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kDeepRose,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Height of MainShell's bottom nav (62) + home-indicator inset.
  /// Returns only the safe-area inset when CartScreen is pushed as a route.
  double _shellNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final insideShell =
        context.findAncestorStateOfType<MainShellState>() != null;
    return insideShell
        ? floatingNavScrollClearance(context, extra: 0)
        : bottomInset;
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C502846),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _kSoftBlush,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder, width: 1.2),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 36,
                  color: _kDeepRose,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your basket is empty',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _kTextCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add fresh blooms to brighten someone\'s day.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: _kMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              RoseButton(
                label: 'Explore Blooms',
                onPressed: () {
                  final shellState =
                      context.findAncestorStateOfType<MainShellState>();
                  if (shellState != null) {
                    shellState.switchToTab(0);
                    return;
                  }
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (_) => false,
                  );
                },
                width: double.infinity,
                icon: Icons.local_florist_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Store-grouped cart list ────────────────────────────────────────────────
  Widget _buildStoreGroupedList(BuildContext context, CartProvider cart) {
    final groups = cart.storeGroups;
    final sortedStoreIds = groups.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + _shellNavClearance(context)),
      children: [
        ...sortedStoreIds.map((storeId) {
          final group = groups[storeId]!;
          return _StoreSection(
            key: ValueKey('store_$storeId'),
            group: group,
            cart: cart,
          );
        }),
        const SizedBox(height: 12),
        _buildOrderSummary(context, cart),
        // Extra space so the last card clears the floating checkout bar.
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A502846),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR BAG',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _kDustyRose,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order Summary',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _kTextCharcoal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kSoftBlush,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: _kBorder, width: 0.8),
                ),
                child: Text(
                  '${cart.itemCount} items',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kDeepRose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.7, color: _kBorder),
          const SizedBox(height: 12),
          _summRow(context, 'All Items (${cart.itemCount})',
              '₱${cart.total.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _summRow(context, 'Selected (${cart.selectedItemCount})',
              '₱${cart.selectedTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _summRow(context, 'Delivery Fee', 'Calculated at checkout'),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.7, color: _kBorder),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Subtotal',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextCharcoal,
                ),
              ),
              Text(
                '₱${cart.selectedTotal.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _kDeepRose,
                ),
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
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            color: _kMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kTextCharcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartProvider cart) {
    final hasSelection = cart.hasSelection;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: _kBorder, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10502846),
            blurRadius: 24,
            offset: Offset(0, -6),
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
                      color: _kDustyRose,
                      letterSpacing: 1.8,
                    ),
                  ),
                  Text(
                    cart.selectedItemCount > 0
                        ? '${cart.selectedItemCount} item${cart.selectedItemCount > 1 ? 's' : ''} selected'
                        : 'No items selected',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
              Text(
                '₱${cart.selectedTotal.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _kDeepRose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RoseButton(
            label: hasSelection
                ? 'Proceed to Checkout (${cart.selectedItemCount})'
                : 'Select items to checkout',
            loading: _checkingDelivery,
            onPressed: hasSelection && !_checkingDelivery
                ? () => _proceedToCheckout(cart)
                : null,
            width: double.infinity,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToCheckout(CartProvider cart) async {
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
      if (!mounted) return;
      if (await maybeShowActiveOrderLimitDialog(
        context,
        message: stockResult.errorMessage,
        data: stockResult.data,
      )) {
        return;
      }
      if (!mounted) return;
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
        if (!mounted) return;
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
      if (!mounted) return;
      _openCheckoutModal(cart, selectedItems);
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

      if (!mounted) return;
      if (isActiveOrderLimitResult(message: error, data: failed)) {
        await showActiveOrderLimitDialogFromPayload(context, data: failed);
        return;
      }

      if (!mounted) return;
      if (isDeliveryUnavailableError(error) ||
          (warnings != null && warnings.isNotEmpty)) {
        await showCheckoutDeliveryUnavailableDialog(
          context,
          reason: error,
          storeDetails: warnings,
        );
        return;
      }

      if (!mounted) return;
      showToast(context, error, isError: true);
      return;
    }

    if (!mounted) return;
    _openCheckoutModal(cart, selectedItems);
  }

  void _openCheckoutModal(
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
        OrdersScreen.reload(targetStatus: 'to_ship');
        showToast(context, 'Order placed successfully!');
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A502846),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Store header with checkbox
          InkWell(
            onTap: () => cart.toggleStoreSelection(group.storeId),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kSoftBlush.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                border: const Border(bottom: BorderSide(color: _kBorder, width: 0.8)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: group.allSelected,
                      tristate: true,
                      onChanged: (_) => cart.toggleStoreSelection(group.storeId),
                      activeColor: _kDeepRose,
                      checkColor: Colors.white,
                      side: const BorderSide(color: _kDustyRose, width: 1.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder, width: 1),
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 15, color: _kDeepRose),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.storeName,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _kTextCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.displayLineCount} item${group.displayLineCount != 1 ? 's' : ''}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${group.selectedSubtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: group.anySelected ? _kDeepRose : _kMuted,
                    ),
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
          // Store subtotal footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder, width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Store Subtotal',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kMuted,
                  ),
                ),
                Text(
                  '₱${group.selectedSubtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: group.anySelected ? _kDeepRose : _kMuted,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _kBorder,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: item.isSelected,
                onChanged: (_) => cart.toggleItemSelection(item.id),
                activeColor: _kDeepRose,
                checkColor: Colors.white,
                side: const BorderSide(color: _kDustyRose, width: 1.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Thumbnail
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 68,
                height: 68,
                child: _buildImage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: item.isSelected ? _kTextCharcoal : _kMuted,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.isVariant)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kSoftBlush,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kBorder, width: 0.8),
                      ),
                      child: Text(
                        'Variant: ${item.variant?.name ?? ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: _kDeepRose,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₱${item.price.toStringAsFixed(2)} each',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                      ),
                    ),
                    if (item.originalPrice != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        '₱${item.originalPrice!.toStringAsFixed(2)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          color: _kMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      if (item.discountPct != null) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _kDeepRose,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${item.discountPct}% OFF',
                            style: GoogleFonts.dmSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _CartQtyControl(
                  qty: item.quantity,
                  onMinus: item.quantity > 1
                      ? () => cart.updateItem(item.id, item.quantity - 1)
                      : null,
                  onPlus: item.quantity < item.stockQuantity
                      ? () => cart.updateItem(item.id, item.quantity + 1)
                      : null,
                ),
                if (item.addons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.addons.map((a) {
                        final label =
                            a.groupName != null && a.groupName!.isNotEmpty
                                ? '${a.groupName}: ${a.name}'
                                : a.name;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kSoftBlush.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorder, width: 0.7),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: a.imageUrl != null && a.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        a.imageUrl!,
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 14,
                                          color: _kDeepRose,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.card_giftcard_rounded,
                                        size: 14,
                                        color: _kDeepRose,
                                      ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '+ $label${a.quantity > 1 ? ' ×${a.quantity}' : ''}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10.5,
                                    color: _kTextCharcoal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₱${(a.price * a.quantity).toStringAsFixed(2)}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: _kDeepRose,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: a.addonOptionId > 0
                                    ? () => cart.removeAddon(item.id, a.addonOptionId)
                                    : null,
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: _kDustyRose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          // Delete item
          GestureDetector(
            onTap: () => cart.removeItem(item.id),
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, left: 4),
              decoration: BoxDecoration(
                color: _kSoftBlush.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: _kDeepRose,
              ),
            ),
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
        color: _kSoftBlush,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _kDeepRose,
            ),
          ),
        ),
      ),
      errorWidget: (_, url, error) {
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
      color: _kSoftBlush,
      child: Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 26,
          color: _kDeepRose.withValues(alpha: 0.3),
        ),
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
        color: _kSoftBlush.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CartQtyBtn(
            icon: Icons.remove_rounded,
            onTap: onMinus,
          ),
          Container(
            width: 30,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: _kBorder, width: 1),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTextCharcoal,
              ),
            ),
          ),
          _CartQtyBtn(
            icon: Icons.add_rounded,
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
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 14,
            color: enabled ? _kTextCharcoal : _kBorder,
          ),
        ),
      ),
    );
  }
}

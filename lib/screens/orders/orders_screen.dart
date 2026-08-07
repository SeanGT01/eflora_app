import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/order.dart';
import '../../models/cart.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'order_detail_screen.dart';
import '../checkout/checkout_modal.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  List<CartItem> _cartItems = [];
  bool _loading = true;
  String _statusFilter = '';
  bool _hasLoadedForUser = false;
  String? _lastUserId;

  final _statusTabs = [
    {'id': '', 'label': 'All'},
    {'id': 'pending', 'label': 'To Pay'},
    {'id': 'to_ship', 'label': 'To Ship'},
    {'id': 'on_delivery', 'label': 'In Transit'},
    {'id': 'delivered', 'label': 'Delivered'},
    {'id': 'completed', 'label': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload orders when auth state changes (login/logout)
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id.toString();
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _hasLoadedForUser = false;
    }
    if (!_hasLoadedForUser && auth.isLoggedIn) {
      _hasLoadedForUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrders();
        context.read<CartProvider>().load();
      });
    } else if (!auth.isLoggedIn) {
      // Guests never hit the API — stop the initial spinner and clear data
      _hasLoadedForUser = false;
      if (_loading || _orders.isNotEmpty || _cartItems.isNotEmpty) {
        setState(() {
          _orders = [];
          _cartItems = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      if (_loading || _orders.isNotEmpty || _cartItems.isNotEmpty) {
        setState(() {
          _orders = [];
          _cartItems = [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);

    // Handle "to_ship" filter: includes preparing, done_preparing, accepted
    String? apiStatus;
    if (_statusFilter.isEmpty) {
      apiStatus = null;
    } else if (_statusFilter == 'to_ship') {
      apiStatus = null; // Load all, then filter locally
    } else if (_statusFilter == 'pending') {
      apiStatus = null; // Load all to show with cart items
    } else {
      apiStatus = _statusFilter;
    }

    // Load cart items ONLY if viewing "To Pay" or "All" tabs
    if (_statusFilter == 'pending' || _statusFilter == '') {
      await context.read<CartProvider>().load();
    }

    final result = await ApiService.getOrders(status: apiStatus);
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      List<dynamic> list =
          data is List ? data : (data is Map ? (data['orders'] ?? []) : []);
      List<Order> orders =
          list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();

      // Filter based on display state (aligned with website purchase history)
      if (_statusFilter == 'to_ship') {
        orders = orders.where((o) => o.displayKey == 'processing').toList();
      } else if (_statusFilter == 'pending') {
        // To Pay: unpaid GCash / cart — exclude COD awaiting confirmation
        orders = orders.where((o) => o.displayKey == 'pending').toList();
      } else if (_statusFilter == 'on_delivery') {
        orders = orders.where((o) => o.displayKey == 'on_delivery').toList();
      } else if (_statusFilter == 'delivered') {
        orders = orders.where((o) => o.displayKey == 'delivered').toList();
      } else if (_statusFilter == 'completed') {
        orders = orders.where((o) => o.displayKey == 'completed').toList();
      }

      setState(() {
        _orders = orders;
        // Only keep cart items if viewing "To Pay" or "All" tabs
        _cartItems = (_statusFilter == 'pending' || _statusFilter == '')
            ? context.read<CartProvider>().items
            : [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      flowerCount: 10,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('My Orders'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Status tabs — wrap like the web filter row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tab in _statusTabs)
                      _StatusTab(
                        label: tab['label']!,
                        selected: _statusFilter == tab['id'],
                        onTap: () {
                          setState(() => _statusFilter = tab['id']!);
                          if (context.read<AuthProvider>().isLoggedIn) {
                            _loadOrders();
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.roseCta))
                    : (_orders.isEmpty && _cartItems.isEmpty)
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.roseCta,
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: (_statusFilter == 'pending' ||
                                          _statusFilter == ''
                                      ? _cartItems.length
                                      : 0) +
                                  _orders.length,
                              itemBuilder: (_, i) {
                                // Show cart items first ONLY if we're viewing "To Pay" or "All" tab
                                final showCartItems =
                                    _statusFilter == 'pending' ||
                                        _statusFilter == '';
                                if (showCartItems && i < _cartItems.length) {
                                  return _CartItemTile(item: _cartItems[i]);
                                }
                                final orderIndex =
                                    showCartItems ? i - _cartItems.length : i;
                                final order = _orders[orderIndex];
                                return GestureDetector(
                                  onTap: () async {
                                    final changed = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              OrderDetailScreen(order: order)),
                                    );
                                    if (changed == true && mounted) {
                                      _loadOrders();
                                    }
                                  },
                                  child: _OrderTile(
                                    order: order,
                                    onOrderUpdated: _loadOrders,
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppColors.imageWash,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.local_florist,
                size: 38, color: Color(0x4DB5445A)),
          ),
          const SizedBox(height: 16),
          Text(
            'ORDERS',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.dustyRose,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text('No orders yet',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Your order history will appear here',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Inactive = translucent white pill with hairline border; active = brand gradient.
class _StatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: selected ? AppShadows.roseButton : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Pill badge using the web's per-status fill / text / border trio.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _OrderTile extends StatefulWidget {
  final Order order;
  final Future<void> Function()? onOrderUpdated;
  const _OrderTile({required this.order, this.onOrderUpdated});

  @override
  State<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<_OrderTile> {
  Map<int, int> _existingRatings = {};
  bool _storeRated = false;
  bool _ratingsLoaded = false;
  bool _expandedItems = false;

  DateTime _toPhilippineTime(DateTime dateTime) {
    // Convert UTC DateTime to Philippine time (UTC+8)
    if (dateTime.isUtc) {
      return dateTime.add(const Duration(hours: 8));
    }
    // If already localized, assume it's in local time and needs conversion
    return dateTime.add(const Duration(hours: 8));
  }

  @override
  void initState() {
    super.initState();
    final s = widget.order.status;
    if (s == 'delivered' || s == 'completed') _loadExistingRatings();
  }

  Future<void> _loadExistingRatings() async {
    final res = await ApiService.getOrderRatings(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      final map = res.data!['ratings'] as Map<String, dynamic>? ?? {};
      final store = res.data!['store_rating'];
      setState(() {
        _existingRatings = map.map(
            (k, v) => MapEntry(int.parse(k), (v['rating'] as num).toInt()));
        _storeRated = store != null;
        _ratingsLoaded = true;
      });
    }
  }

  bool get _allRated =>
      _ratingsLoaded &&
      _storeRated &&
      widget.order.items.every((i) => _existingRatings.containsKey(i.id));

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final computedTotal = order.subtotalAmount + order.deliveryFee;
    final totalToShow = (order.totalAmount <= 0 ||
            (order.totalAmount - computedTotal).abs() > 0.05)
        ? computedTotal
        : order.totalAmount;
    final dateStr = order.createdAt != null
        ? DateFormat('MMM dd, yyyy').format(_toPhilippineTime(order.createdAt!))
        : '—';
    final hasMultipleItems = order.items.length > 1;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      radius: AppRadius.xl,
      tinted: true,
      child: Column(
        children: [
          // Header with store name and status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.storeName != null)
                        Text(
                          order.storeName!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.labelPink,
                            letterSpacing: 1.4,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.dmSans(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(
                  label: order.statusLabel,
                  background: order.statusBackgroundColor,
                  foreground: order.statusColor,
                  borderColor: order.statusBorderColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // First product card
          if (order.items.isNotEmpty)
            _TikTokProductCard(item: order.items.first, isLast: false),

          // Expandable additional items
          if (hasMultipleItems) ...[
            if (!_expandedItems) ...[
              // View more button (when collapsed)
              GestureDetector(
                onTap: () => setState(() => _expandedItems = !_expandedItems),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Text(
                        'View more ${order.items.length - 1} item${order.items.length > 2 ? 's' : ''}',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dustyRose),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more,
                        color: AppColors.dustyRose,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Additional products (when expanded)
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...order.items.skip(1).toList().asMap().entries.map((e) {
                final item = e.value;
                return _TikTokProductCard(item: item, isLast: false);
              }),

              // View less button (when expanded)
              GestureDetector(
                onTap: () => setState(() => _expandedItems = !_expandedItems),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Text(
                        'View less',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dustyRose),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_less,
                        color: AppColors.dustyRose,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          // Price & Action buttons footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side - empty for now
                const SizedBox(width: 1),

                // Right side - price and buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ₱${totalToShow.toStringAsFixed(2)}',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepRose),
                    ),
                    const SizedBox(height: 10),

                    // Action buttons (stacked horizontally, smaller)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Buy Again button
                        if (order.status == 'delivered' ||
                            order.status == 'completed')
                          GestureDetector(
                            onTap: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Order Again feature coming soon')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.glassFill,
                                border:
                                    Border.all(color: AppColors.glassBorder),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Buy Again',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoal,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),

                        // Rate button
                        if ((order.status == 'delivered' ||
                                order.status == 'completed') &&
                            _ratingsLoaded &&
                            !_allRated)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDetailScreen(order: order)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                boxShadow: AppShadows.roseButton,
                              ),
                              child: Text(
                                'Rate',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (order.status == 'delivered') ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _markAsCompletedFromCard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0x80C8E6D2),
                                border:
                                    Border.all(color: const Color(0x597A9E7E)),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Complete',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF3F6B4E),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (order.canCancel) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _cancelOrderFromCard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0x1FC24E68),
                                border:
                                    Border.all(color: const Color(0x40C24E68)),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9B1C1C),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrderFromCard() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: Text(
              'Cancel order?',
              style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            content: Text(
              'This cannot be undone. The store will be notified.',
              style: GoogleFonts.dmSans(color: AppColors.muted, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Keep order',
                    style: GoogleFonts.dmSans(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Cancel order',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF9B1C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    final res = await ApiService.cancelOrder(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
      await widget.onOrderUpdated?.call();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Could not cancel order')),
    );
  }

  Future<void> _markAsCompletedFromCard() async {
    final res = await ApiService.completeOrder(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as completed.')),
      );
      await widget.onOrderUpdated?.call();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Failed to complete order')),
    );
  }
}

class _TikTokProductCard extends StatelessWidget {
  final OrderItem item;
  final bool isLast;

  const _TikTokProductCard({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: AppColors.imageWash,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _ImagePlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const _ImagePlaceholder(),
                        ),
                      )
                    : const _ImagePlaceholder(),
              ),
              const SizedBox(width: 12),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${item.quantity}',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),

                    // Price
                    Text(
                      '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepRose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rose bloom over the pink/lavender wash, matching the web's empty thumbnails.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.iconSize = 26});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Icon(Icons.local_florist,
            size: iconSize, color: const Color(0x33B5445A)),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      radius: AppRadius.xl,
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Basket',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const _StatusPill(
                label: 'To Pay',
                background: Color(0x73FFD2B4),
                foreground: Color(0xFFA06030),
                borderColor: Color(0x66E8A078),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item.storeName != null)
            Row(children: [
              const Icon(Icons.storefront_outlined,
                  size: 12, color: AppColors.labelPink),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.storeName!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.labelPink,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ]),
          const Divider(height: 20),
          // Item details
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.name} × ${item.quantity}',
                  style: GoogleFonts.dmSans(
                      fontSize: 12.5, color: AppColors.charcoal),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal),
                  ),
                  if (item.originalPrice != null)
                    Text(
                      'Was ₱${(item.originalPrice! * item.quantity).toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: Theme.of(context).textTheme.titleSmall),
              Text(
                '₱${item.subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Go to Checkout',
            height: 48,
            onPressed: () {
              // Open checkout modal with cart item
              final cartItems = [item];
              showCheckoutModal(
                context,
                selectedItems: cartItems,
                onComplete: () {
                  // Refresh orders and cart after successful checkout
                  // Pop the orders screen to trigger a reload
                  Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

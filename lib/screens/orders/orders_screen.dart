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
import '../../widgets/cancel_order_reason_sheet.dart';
import 'order_detail_screen.dart';
import '../checkout/checkout_modal.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _allOrders = [];
  List<Order> _orders = [];
  List<CartItem> _cartItems = [];
  bool _loading = true;
  String _statusFilter = '';
  bool _hasLoadedForUser = false;
  String? _lastUserId;
  final _statusScroll = ScrollController();

  final _statusTabs = [
    {'id': '', 'label': 'All'},
    {'id': 'pending', 'label': 'To Pay'},
    {'id': 'to_ship', 'label': 'To Ship'},
    {'id': 'on_delivery', 'label': 'To Receive'},
    {'id': 'delivered', 'label': 'Delivered'},
    {'id': 'completed', 'label': 'Completed'},
    {'id': 'cancelled', 'label': 'Cancelled'},
  ];

  int _countFor(String id) {
    final cartN = _cartItems.length;
    if (id.isEmpty) return cartN + _allOrders.length;
    if (id == 'pending') {
      return cartN +
          _allOrders.where((o) => o.displayKey == 'pending').length;
    }
    final key = id == 'to_ship' ? 'processing' : id;
    return _allOrders.where((o) => o.displayKey == key).length;
  }

  List<Order> _filtered(List<Order> source) {
    if (_statusFilter.isEmpty) return List<Order>.from(source);
    if (_statusFilter == 'to_ship') {
      return source.where((o) => o.displayKey == 'processing').toList();
    }
    if (_statusFilter == 'pending') {
      return source.where((o) => o.displayKey == 'pending').toList();
    }
    return source.where((o) => o.displayKey == _statusFilter).toList();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _statusScroll.dispose();
    super.dispose();
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
          _allOrders = [];
          _orders = [];
          _cartItems = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      if (_loading || _orders.isNotEmpty || _cartItems.isNotEmpty) {
        setState(() {
          _allOrders = [];
          _orders = [];
          _cartItems = [];
          _loading = false;
        });
      }
      return;
    }
    if (!silent) {
      setState(() => _loading = true);
    }

    await context.read<CartProvider>().load();

    final allOrders = await _fetchAllOrderPages();
    if (!mounted) return;
    if (allOrders != null) {
      setState(() {
        _allOrders = allOrders;
        _cartItems = context.read<CartProvider>().items;
        _orders = _filtered(allOrders);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<List<Order>?> _fetchAllOrderPages() async {
    final collected = <Order>[];
    var page = 1;
    while (page <= 50) {
      final result = await ApiService.getOrders(page: page);
      if (!result.isSuccess) {
        return page == 1 ? null : collected;
      }
      final data = result.data;
      final list = data is List
          ? data
          : (data is Map ? (data['orders'] ?? []) : []);
      collected.addAll(
        (list as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>)),
      );
      final hasNext = data is Map && data['has_next'] == true;
      if (!hasNext) break;
      page++;
    }
    return collected;
  }

  void _applyCancelledLocally(int orderId) {
    setState(() {
      _allOrders = _allOrders
          .map((o) => o.id == orderId ? o.copyWith(status: 'cancelled') : o)
          .toList();
      _orders = _filtered(_allOrders);
    });
  }

  Future<void> _onOrderCancelled(int orderId) async {
    _applyCancelledLocally(orderId);
    await _loadOrders(silent: true);
  }

  /// After marking delivered → completed, follow the order into the Completed tab.
  Future<void> _onOrderCompleted() async {
    if (_statusFilter == 'delivered') {
      setState(() => _statusFilter = 'completed');
    }
    await _loadOrders(silent: true);
  }

  void _selectStatus(String id) {
    setState(() {
      _statusFilter = id;
      _orders = _filtered(_allOrders);
    });
  }

  Widget _buildStatusChipRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: ListView.builder(
            controller: _statusScroll,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _statusTabs.length,
            itemBuilder: (_, i) {
              final tab = _statusTabs[i];
              return _StatusTab(
                label: tab['label']!,
                count: _countFor(tab['id']!),
                selected: _statusFilter == tab['id'],
                onTap: () => _selectStatus(tab['id']!),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 0.6, color: Color(0x1A2C2520)),
      ],
    );
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
              const SizedBox(height: 2),
              _buildStatusChipRow(),
              const SizedBox(height: 4),
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.roseCta))
                    : _isListEmpty
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
                                      await _onOrderCompleted();
                                    }
                                  },
                                  child: _OrderTile(
                                    order: order,
                                    onOrderUpdated: _loadOrders,
                                    onOrderCompleted: _onOrderCompleted,
                                    onOrderCancelled: _onOrderCancelled,
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

  bool get _isListEmpty {
    final showCart =
        _statusFilter == 'pending' || _statusFilter.isEmpty;
    if (showCart) return _orders.isEmpty && _cartItems.isEmpty;
    return _orders.isEmpty;
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

class _StatusTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _StatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = count > 0;
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.roseCta.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: 8,
                    right: showBadge ? 12 : 0,
                    bottom: 8,
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.roseCta : AppColors.muted,
                      height: 1.1,
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 2,
                    right: -2,
                    child: _StatusCountBadge(count: count),
                  ),
              ],
            ),
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              height: 2.5,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: AppColors.roseCta,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCountBadge extends StatelessWidget {
  final int count;

  const _StatusCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: EdgeInsets.symmetric(horizontal: text.length > 1 ? 4 : 0),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.roseCta,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
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
  final Future<void> Function()? onOrderCompleted;
  final Future<void> Function(int orderId)? onOrderCancelled;
  const _OrderTile({
    required this.order,
    this.onOrderUpdated,
    this.onOrderCompleted,
    this.onOrderCancelled,
  });

  @override
  State<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<_OrderTile> {
  Map<int, int> _existingRatings = {};
  bool _storeRated = false;
  bool _ratingsLoaded = false;
  bool _expandedItems = false;
  bool _buyAgainBusy = false;

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

  /// Mirrors web `reorderItems`: fetch order lines, add each as qty 1.
  Future<void> _buyAgain() async {
    if (_buyAgainBusy) return;
    setState(() => _buyAgainBusy = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Adding items to cart…')),
    );

    try {
      final res = await ApiService.getOrder(widget.order.id);
      if (!mounted) return;

      List<OrderItem> items = widget.order.items;
      if (res.isSuccess && res.data is Map) {
        final parsed = Order.fromJson(Map<String, dynamic>.from(res.data as Map));
        if (parsed.items.isNotEmpty) items = parsed.items;
      }

      if (items.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('No items found in this order.')),
        );
        return;
      }

      final cart = context.read<CartProvider>();
      var added = 0;
      var skipped = 0;

      for (final item in items) {
        if (item.productId <= 0) {
          skipped++;
          continue;
        }
        final err = await cart.addItem(
          item.productId,
          qty: 1,
          variantId: item.variantId,
          addonOptionIds: item.reorderAddonOptionIds.isEmpty
              ? null
              : item.reorderAddonOptionIds,
        );
        if (err == null) {
          added++;
        } else {
          skipped++;
        }
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (added > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$added item${added == 1 ? '' : 's'} added to cart'
              '${skipped > 0 ? ' ($skipped out of stock)' : ''}',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('All items are out of stock.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to reorder. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _buyAgainBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final itemsSubtotal = order.items.fold<double>(0, (s, i) => s + i.lineTotal);
    final hasAddons = order.items.any((i) => i.addons.isNotEmpty || i.addonsTotal > 0);
    final subtotalToUse = (hasAddons && itemsSubtotal > 0)
        ? itemsSubtotal
        : (itemsSubtotal > order.subtotalAmount + 0.009
            ? itemsSubtotal
            : order.subtotalAmount);
    final computedTotal = subtotalToUse + order.deliveryFee;
    final totalToShow = (hasAddons || order.totalAmount <= 0 ||
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
                            onTap: _buyAgainBusy ? null : _buyAgain,
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
                              child: _buyAgainBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.charcoal,
                                      ),
                                    )
                                  : Text(
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
                            onTap: _openOrderForRating,
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
    final reason = await showCancelOrderReasonSheet(context);
    if (reason == null || !mounted) return;

    final res = await ApiService.cancelOrder(
      widget.order.id,
      reasonCode: reason.reasonCode,
      reason: reason.reason,
    );
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
      if (widget.onOrderCancelled != null) {
        await widget.onOrderCancelled!(widget.order.id);
      } else {
        await widget.onOrderUpdated?.call();
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Could not cancel order')),
    );
  }

  Future<void> _notifyCompleted() async {
    if (widget.onOrderCompleted != null) {
      await widget.onOrderCompleted!();
    } else {
      await widget.onOrderUpdated?.call();
    }
  }

  Future<void> _markAsCompletedFromCard() async {
    final res = await ApiService.completeOrder(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as completed.')),
      );
      await _notifyCompleted();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Failed to complete order')),
    );
  }

  Future<void> _openOrderForRating() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: widget.order),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      await _notifyCompleted();
    } else {
      await widget.onOrderUpdated?.call();
    }
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
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.charcoal),
                          ),
                        ),
                        if (item.rating != null && item.rating! >= 1) ...[
                          const SizedBox(width: 6),
                          _ItemRatingStars(rating: item.rating!),
                        ],
                      ],
                    ),
                    if (item.variantName != null &&
                        item.variantName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Variant: ${item.variantName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.deepRose,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Qty: ${item.quantity}',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    if (item.addons.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      ...item.addons.take(2).map(
                            (a) => Text(
                              '+ ${a.name}${a.quantity > 1 ? ' ×${a.quantity}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                    ],
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

class _ItemRatingStars extends StatelessWidget {
  final int rating;
  const _ItemRatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 13,
          color: filled ? const Color(0xFFF0B429) : const Color(0x382C2520),
        );
      }),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.name} × ${item.quantity}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12.5, color: AppColors.charcoal),
                    ),
                    if (item.addons.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...item.addons.map(
                        (a) => Text(
                          '+ ${a.name}${a.quantity > 1 ? ' ×${a.quantity}' : ''}'
                          '  ₱${(a.price * a.quantity).toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${item.subtotal.toStringAsFixed(2)}',
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

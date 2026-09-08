import 'dart:async';
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
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/cancel_order_reason_sheet.dart';
import '../../widgets/order_review_dialog.dart';
import '../../navigation/floating_nav_metrics.dart';
import 'order_detail_screen.dart';
import '../checkout/checkout_modal.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  /// Global notifier to trigger an immediate orders refresh and optional status tab switch.
  /// Holds (targetStatus, reloadToken) so that every call notifies listeners even if targetStatus is unchanged.
  static final ValueNotifier<({String? status, int token})> reloadNotifier =
      ValueNotifier<({String? status, int token})>((status: null, token: 0));

  /// Trigger a reload of orders, optionally switching to a target status tab (e.g. 'to_ship' or '').
  static void reload({String? targetStatus}) {
    reloadNotifier.value = (
      status: targetStatus,
      token: reloadNotifier.value.token + 1,
    );
  }

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
  Timer? _pollTimer;

  final _statusTabs = [
    {'id': '', 'label': 'All'},
    {'id': 'pending', 'label': 'To Pay'},
    {'id': 'to_ship', 'label': 'To Ship'},
    {'id': 'on_delivery', 'label': 'To Receive'},
    {'id': 'delivered', 'label': 'Delivered'},
    {'id': 'completed', 'label': 'Completed'},
    {'id': 'cancelled', 'label': 'Cancelled'},
  ];

  List<StoreCartGroup> get _cartGroups {
    final groups = <int, StoreCartGroup>{};
    for (final item in _cartItems) {
      final sid = item.storeId ?? 0;
      if (!groups.containsKey(sid)) {
        final finalStoreName = (item.storeName?.isNotEmpty ?? false)
            ? item.storeName!
            : 'Store';
        groups[sid] = StoreCartGroup(
          storeId: sid,
          storeName: finalStoreName,
          items: [],
        );
      }
      groups[sid]!.items.add(item);
    }
    return groups.values.toList();
  }

  int _countFor(String id) {
    final cartN = _cartGroups.length;
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
    OrdersScreen.reloadNotifier.addListener(_onReloadNotified);
    _startPolling();
  }

  void _onReloadNotified() {
    if (!mounted) return;
    final info = OrdersScreen.reloadNotifier.value;
    if (info.token > 0) {
      final targetStatus = info.status;
      if (targetStatus != null && targetStatus.isNotEmpty) {
        _statusFilter = targetStatus;
        final tabIndex = _statusTabs.indexWhere((t) => t['id'] == targetStatus);
        if (tabIndex != -1 && _statusScroll.hasClients) {
          _statusScroll.animateTo(
            (tabIndex * 85.0).clamp(0.0, _statusScroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
      // When explicitly navigated/reloaded (such as tapping Orders in navbar),
      // allow review popup check again.
      _hasCheckedAutoPopup = false;
      _loadOrders(silent: false, forceCheckPopup: true);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll every 8 seconds in the background so status transitions (e.g. pending -> to_ship -> on_delivery)
    // and new orders move across status panes automatically without manual refresh.
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && context.read<AuthProvider>().isLoggedIn) {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    OrdersScreen.reloadNotifier.removeListener(_onReloadNotified);
    _pollTimer?.cancel();
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

  bool _hasCheckedAutoPopup = false;
  bool _isAutoPopupOpen = false;

  Future<void> _loadOrders({bool silent = false, bool forceCheckPopup = false}) async {
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
      if ((!_hasCheckedAutoPopup || forceCheckPopup) && !silent) {
        _hasCheckedAutoPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoReviewPrompt(allOrders);
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkAutoReviewPrompt(List<Order> orders) async {
    if (!mounted || _isAutoPopupOpen) return;
    _isAutoPopupOpen = true;

    try {
      // Keep looping until there are no more unrated completed/delivered orders,
      // OR until the user explicitly closes/skips without submitting a rating.
      var pendingOrders = orders;
      while (mounted) {
        // Filter candidates fresh each iteration (list is updated after each rating).
        final candidates = pendingOrders.where((o) {
          final s = o.status;
          return (s == 'delivered' || s == 'completed') && !o.allRated;
        }).toList();

        if (candidates.isEmpty) break;

        // Sort ascending by createdAt so earliest unrated order is prompted first.
        candidates.sort((a, b) {
          final da = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final db = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return da.compareTo(db);
        });

        final targetOrder = candidates.first;
        final updated = await showOrderReviewModal(context, order: targetOrder);
        if (!mounted) break;

        // If user closed/skipped the modal without submitting any rating, stop the
        // loop entirely — don't re-prompt the same or next order in this session.
        if (updated != true) break;

        // A rating was submitted — re-fetch so the next iteration reflects fresh data.
        final freshOrders = await _fetchAllOrderPages();
        if (!mounted) break;
        if (freshOrders != null) {
          setState(() {
            _allOrders = freshOrders;
            _orders = _filtered(freshOrders);
          });
          pendingOrders = freshOrders;
        } else {
          break;
        }
      }
    } finally {
      _isAutoPopupOpen = false;
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
                            child: Builder(
                              builder: (context) {
                                final showCartItems =
                                    _statusFilter == 'pending' ||
                                        _statusFilter == '';
                                final cartGroups = showCartItems
                                    ? _cartGroups
                                    : const <StoreCartGroup>[];

                                return ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    floatingNavScrollClearance(context),
                                  ),
                                  itemCount: cartGroups.length + _orders.length,
                                  itemBuilder: (_, i) {
                                    if (i < cartGroups.length) {
                                      final group = cartGroups[i];
                                      return _StoreToPayCard(
                                        key: ValueKey('cart_group_${group.storeId}'),
                                        group: group,
                                      );
                                    }
                                    final orderIndex = i - cartGroups.length;
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
    if (showCart) return _orders.isEmpty && _cartGroups.isEmpty;
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

    showToast(context, 'Adding items to cart…');

    try {
      final res = await ApiService.getOrder(widget.order.id);
      if (!mounted) return;

      List<OrderItem> items = widget.order.items;
      if (res.isSuccess && res.data is Map) {
        final parsed = Order.fromJson(Map<String, dynamic>.from(res.data as Map));
        if (parsed.items.isNotEmpty) items = parsed.items;
      }

      if (items.isEmpty) {
        showToast(context, 'No items found in this order.', isError: true);
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
      if (added > 0) {
        showToast(
          context,
          '$added item${added == 1 ? '' : 's'} added to cart'
          '${skipped > 0 ? ' ($skipped out of stock)' : ''}',
        );
      } else {
        showToast(context, 'All items are out of stock.', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Failed to reorder. Please try again.', isError: true);
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
                            (!order.allRated || (_ratingsLoaded && !_allRated)))
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
                                gradient: AppColors.brandGradient,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                boxShadow: AppShadows.roseButton,
                              ),
                              child: Text(
                                'Complete',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
      showToast(context, 'Order cancelled.');
      if (widget.onOrderCancelled != null) {
        await widget.onOrderCancelled!(widget.order.id);
      } else {
        await widget.onOrderUpdated?.call();
      }
      return;
    }
    showToast(
      context,
      (res.data?['message'] ?? res.data?['error'] ?? 'Could not cancel order')
          .toString(),
      isError: true,
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
      showToast(context, 'Order marked as completed.');
      await _notifyCompleted();
      return;
    }
    showToast(
      context,
      (res.data?['message'] ?? res.data?['error'] ?? 'Failed to complete order')
          .toString(),
      isError: true,
    );
  }

  Future<void> _openOrderForRating() async {
    final updated = await showOrderReviewModal(
      context,
      order: widget.order,
      initialExistingRatings: _ratingsLoaded ? _existingRatings : null,
      initialStoreRated: _ratingsLoaded ? _storeRated : null,
    );
    if (!mounted) return;
    if (updated == true) {
      await _loadExistingRatings();
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
  const _ImagePlaceholder();

  static const double _iconSize = 26;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Icon(Icons.local_florist,
            size: _iconSize, color: Color(0x33B5445A)),
      ),
    );
  }
}

class _StoreToPayCard extends StatefulWidget {
  final StoreCartGroup group;
  const _StoreToPayCard({super.key, required this.group});

  @override
  State<_StoreToPayCard> createState() => _StoreToPayCardState();
}

class _StoreToPayCardState extends State<_StoreToPayCard> {
  bool _expanded = false;

  void _openCheckout() {
    showCheckoutModal(
      context,
      selectedItems: widget.group.items,
      onComplete: () {
        context.read<CartProvider>().load();
        OrdersScreen.reload(targetStatus: 'to_ship');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final hasMultipleItems = group.items.length > 1;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      radius: AppRadius.xl,
      tinted: true,
      child: Column(
        children: [
          // Header with store name and status pill (matches _OrderTile)
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
                      Text(
                        group.storeName.toUpperCase(),
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
                        'Pending payment • ${group.items.length} ${group.items.length == 1 ? 'item' : 'items'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _StatusPill(
                  label: 'TO PAY',
                  background: Color(0x73FFD2B4),
                  foreground: Color(0xFFA06030),
                  borderColor: Color(0x66E8A078),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // First product card (matches _TikTokProductCard in _OrderTile)
          if (group.items.isNotEmpty)
            _CartProductRow(item: group.items.first),

          // Expandable additional items (matches _OrderTile)
          if (hasMultipleItems) ...[
            if (!_expanded) ...[
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Text(
                        'View more ${group.items.length - 1} item${group.items.length > 2 ? 's' : ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dustyRose,
                        ),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...group.items.skip(1).map((item) => _CartProductRow(item: item)),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
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
                          color: AppColors.dustyRose,
                        ),
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

          // Footer with subtotal and Pay Now action button (matches _OrderTile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(width: 1),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ₱${group.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRose,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _openCheckout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 7.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.roseButton,
                        ),
                        child: Text(
                          'Pay Now',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
}

class _CartProductRow extends StatelessWidget {
  final CartItem item;
  const _CartProductRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final imgUrl = item.imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image (62x62 matching _TikTokProductCard)
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: AppColors.imageWash,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: imgUrl != null && imgUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _ImagePlaceholder(),
                      errorWidget: (_, __, ___) => const _ImagePlaceholder(),
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
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.variant != null && item.variant!.name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Variant: ${item.variant!.name}',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${item.quantity}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      '₱${item.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...item.addons.take(2).map(
                    (a) => Text(
                      '+ ${a.name}${a.quantity > 1 ? ' ×${a.quantity}' : ''}'
                      '  ₱${(a.price * a.quantity).toStringAsFixed(2)}',
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
    );
  }
}

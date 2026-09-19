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
import '../../widgets/common.dart';
import '../../widgets/cancel_order_reason_sheet.dart';
import '../../widgets/order_review_dialog.dart';
import '../../navigation/floating_nav_metrics.dart';
import 'order_detail_screen.dart';
import '../checkout/checkout_modal.dart';

const _kDeepRose = Color(0xFFB5445A);
const _kDustyRose = Color(0xFFD4788A);
const _kSoftBlush = Color(0xFFFBE9EE);
const _kTextCharcoal = Color(0xFF2C2520);
const _kMuted = Color(0xFF8F7D79);
const _kBorder = Color(0xFFF0DDE2);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  /// Global notifier to trigger an immediate orders refresh and optional status tab switch.
  /// Holds (targetStatus, targetOrderId, reloadToken) so that every call notifies listeners.
  static final ValueNotifier<({String? status, int? orderId, int token})> reloadNotifier =
      ValueNotifier<({String? status, int? orderId, int token})>((status: null, orderId: null, token: 0));

  /// Trigger a reload of orders, optionally switching to a target status tab and opening a specific order.
  static void reload({String? targetStatus, int? targetOrderId}) {
    reloadNotifier.value = (
      status: targetStatus,
      orderId: targetOrderId,
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
    {'id': '', 'label': 'All', 'icon': Icons.receipt_long_outlined},
    {'id': 'pending', 'label': 'To Pay', 'icon': Icons.credit_card_outlined},
    {'id': 'to_ship', 'label': 'To Ship', 'icon': Icons.local_shipping_outlined},
    {'id': 'on_delivery', 'label': 'To Receive', 'icon': Icons.shopping_bag_outlined},
    {'id': 'delivered', 'label': 'Delivered', 'icon': Icons.assignment_turned_in_outlined},
    {'id': 'completed', 'label': 'Completed', 'icon': Icons.task_alt_rounded},
    {'id': 'cancelled', 'label': 'Cancelled', 'icon': Icons.cancel_outlined},
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

  int _lastHandledToken = 0;
  bool _isFetchingOrders = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      final cached = ApiService.getCachedOrders();
      if (cached != null && cached.isNotEmpty) {
        _allOrders = cached.map((e) => Order.fromJson(e)).toList();
        _orders = _filtered(_allOrders);
        _loading = false;
      }
    } else {
      _allOrders = [];
      _orders = [];
      _loading = false;
    }
    OrdersScreen.reloadNotifier.addListener(_onReloadNotified);
    _startPolling();
    if (OrdersScreen.reloadNotifier.value.token > 0 && auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onReloadNotified();
      });
    }
  }

  void _onReloadNotified() {
    if (!mounted) return;
    if (!context.read<AuthProvider>().isLoggedIn) {
      setState(() {
        _allOrders = [];
        _orders = [];
        _cartItems = [];
        _loading = false;
      });
      return;
    }
    final info = OrdersScreen.reloadNotifier.value;
    if (info.token > _lastHandledToken) {
      _lastHandledToken = info.token;
      final targetStatus = info.status;
      final targetOrderId = info.orderId;
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
      _loadOrders(silent: _allOrders.isNotEmpty, forceCheckPopup: true, targetOrderIdToOpen: targetOrderId);
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
      _lastHandledToken = 0;
    }
    if (!_hasLoadedForUser && auth.isLoggedIn) {
      _hasLoadedForUser = true;
      if (OrdersScreen.reloadNotifier.value.token == 0 || _lastHandledToken == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lastHandledToken == 0) {
            _loadOrders(silent: _allOrders.isNotEmpty);
            context.read<CartProvider>().load(showLoading: false);
          }
        });
      }
    } else if (!auth.isLoggedIn) {
      // Guests never hit the API — stop the initial spinner, clear cached orders and data
      _hasLoadedForUser = false;
      _lastHandledToken = 0;
      _hasCheckedAutoPopup = true;
      if (_loading || _allOrders.isNotEmpty || _orders.isNotEmpty || _cartItems.isNotEmpty) {
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

  Future<void> _loadOrders({bool silent = false, bool forceCheckPopup = false, int? targetOrderIdToOpen}) async {
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
    if (_isFetchingOrders && silent) return;
    _isFetchingOrders = true;

    if (!silent && _allOrders.isEmpty) {
      setState(() => _loading = true);
    }

    try {
      final allOrders = await _fetchAllOrderPages();
      if (!mounted) return;
      if (allOrders != null) {
        setState(() {
          _allOrders = allOrders;
          _cartItems = context.read<CartProvider>().items;
          _orders = _filtered(allOrders);
          _loading = false;
        });

        if (targetOrderIdToOpen != null && targetOrderIdToOpen > 0) {
          final matches = allOrders.where((o) => o.id == targetOrderIdToOpen).toList();
          if (matches.isNotEmpty) {
            final targetOrder = matches.first;
            if (targetOrder.displayKey.isNotEmpty) {
              setState(() {
                _statusFilter = targetOrder.displayKey;
                _orders = _filtered(allOrders);
              });
              final tabIndex = _statusTabs.indexWhere((t) => t['id'] == targetOrder.displayKey);
              if (tabIndex != -1 && _statusScroll.hasClients) {
                _statusScroll.animateTo(
                  (tabIndex * 85.0).clamp(0.0, _statusScroll.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: targetOrder)),
                );
              }
            });
          }
        }

        if ((!_hasCheckedAutoPopup || forceCheckPopup) && !silent && targetOrderIdToOpen == null) {
          _hasCheckedAutoPopup = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAutoReviewPrompt(allOrders);
          });
        }
      } else {
        setState(() => _loading = false);
      }
    } finally {
      _isFetchingOrders = false;
    }
  }

  Future<void> _checkAutoReviewPrompt(List<Order> orders) async {
    if (!mounted || _isAutoPopupOpen) return;
    if (!context.read<AuthProvider>().isLoggedIn) return;
    _isAutoPopupOpen = true;

    try {
      var pendingOrders = orders;
      while (mounted) {
        if (!context.read<AuthProvider>().isLoggedIn) break;
        final now = DateTime.now();
        final candidates = pendingOrders.where((o) {
          final s = o.status;
          final isDelivered = (s == 'delivered' || s == 'completed');
          final isRecent = o.createdAt != null &&
              now.difference(o.createdAt!).inDays <= 30;
          return isDelivered && !o.allRated && isRecent;
        }).toList();

        if (candidates.isEmpty) break;

        candidates.sort((a, b) {
          final da = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final db = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return da.compareTo(db);
        });

        final targetOrder = candidates.first;
        final updated = await showOrderReviewModal(context, order: targetOrder);
        if (!mounted || !context.read<AuthProvider>().isLoggedIn) break;

        if (updated != true) break;

        final freshOrders = await _fetchAllOrderPages();
        if (!mounted || !context.read<AuthProvider>().isLoggedIn) break;
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
    final rawList = <Map<String, dynamic>>[];
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
      for (final item in (list as List)) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          rawList.add(map);
          collected.add(Order.fromJson(map));
        }
      }
      final hasNext = data is Map && data['has_next'] == true;
      if (!hasNext) break;
      page++;
    }
    if (rawList.isNotEmpty) {
      ApiService.updateCachedOrders(rawList);
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

  Widget _buildTopBrandHeader() {
    return const EfloraTopBar();
  }

  Widget _buildHeroHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative floral artwork on upper right
          Positioned(
            top: -16,
            right: 0,
            width: 140,
            height: 110,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  'assets/images/eflora_orders_header_floral.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          // Heading text on left
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My Orders',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _kTextCharcoal,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your orders and blossoms',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _kMuted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChipRow() {
    return Container(
      height: 72,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        controller: _statusScroll,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _statusTabs.length,
        itemBuilder: (_, i) {
          final tab = _statusTabs[i];
          final id = tab['id'] as String;
          final label = tab['label'] as String;
          final icon = tab['icon'] as IconData;
          return _StatusTab(
            label: label,
            icon: icon,
            count: _countFor(id),
            selected: _statusFilter == id,
            onTap: () => _selectStatus(id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBrandHeader(),
              _buildHeroHeader(),
              _buildStatusChipRow(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kDeepRose),
                      )
                    : _isListEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: _kDeepRose,
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
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    floatingNavScrollClearance(context) + 20,
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
                                                OrderDetailScreen(order: order),
                                          ),
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _kSoftBlush,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C502846),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_florist_rounded,
                size: 40,
                color: _kDeepRose,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No orders yet',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _kTextCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your blooms and order history will appear here',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _kMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _StatusTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = count > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: _kDeepRose.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? _kSoftBlush
                        : Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? const Color(0xFFF4C5CE) : _kBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? _kDeepRose : _kMuted,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: _StatusCountBadge(count: count),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _kDeepRose : _kTextCharcoal.withValues(alpha: 0.8),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: selected ? 20 : 0,
              decoration: BoxDecoration(
                color: _kDeepRose,
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
      padding: EdgeInsets.symmetric(horizontal: text.length > 1 ? 4 : 2),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFC83757),
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// Pill badge with per-status fill / text / border styling.
class _StatusPill extends StatelessWidget {
  final String label;
  final String? statusKey;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;

  const _StatusPill({
    required this.label,
    this.statusKey,
    this.background,
    this.foreground,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = background ?? _kSoftBlush;
    Color fg = foreground ?? _kDeepRose;
    Color border = borderColor ?? const Color(0xFFF4C5CE);

    if (statusKey != null && statusKey!.isNotEmpty) {
      switch (statusKey!.toLowerCase()) {
        case 'pending':
          bg = const Color(0xFFFBE9EE);
          fg = const Color(0xFFB5445A);
          border = const Color(0xFFF4C5CE);
          break;
        case 'processing':
        case 'to_ship':
          bg = const Color(0xFFFFF1E6);
          fg = const Color(0xFFC98245);
          border = const Color(0xFFFFDFC5);
          break;
        case 'on_delivery':
        case 'to_receive':
          bg = const Color(0xFFEEF2FA);
          fg = const Color(0xFF4A6DA7);
          border = const Color(0xFFD0E0FC);
          break;
        case 'delivered':
          bg = const Color(0xFFF0F7EE);
          fg = const Color(0xFF3D8B4E);
          border = const Color(0xFFC6E7CE);
          break;
        case 'completed':
          bg = const Color(0xFFE8F3E8);
          fg = const Color(0xFF5A8D62);
          border = const Color(0xFFC3E6CB);
          break;
        case 'cancelled':
          bg = const Color(0xFFFCEDEF);
          fg = const Color(0xFFC94343);
          border = const Color(0xFFF5C6CB);
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
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
    if (dateTime.isUtc) {
      return dateTime.add(const Duration(hours: 8));
    }
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

  bool get _isFullyRated {
    if (widget.order.allRated) return true;
    if (!_ratingsLoaded) return false;
    final rateable = widget.order.items
        .where((i) => !i.productName.startsWith('[Deleted'))
        .toList();
    final itemsOk = rateable.isEmpty ||
        rateable.every((i) => _existingRatings.containsKey(i.id));
    return _storeRated && itemsOk;
  }

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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C502846),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with store name, date, and status pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order.storeName ?? 'E-FLORA').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kDeepRose,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(
                  label: order.statusLabel,
                  statusKey: order.displayKey,
                  background: order.statusBackgroundColor,
                  foreground: order.statusColor,
                  borderColor: order.statusBorderColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.6, color: _kBorder, indent: 16, endIndent: 16),

          // First product card
          if (order.items.isNotEmpty)
            _ProductItemRow(
              item: order.items.first,
              showPrice: true,
              priceOverride: !hasMultipleItems ? totalToShow : null,
            ),

          // Expandable additional items
          if (hasMultipleItems) ...[
            if (!_expandedItems) ...[
              // View more button (when collapsed)
              InkWell(
                onTap: () => setState(() => _expandedItems = !_expandedItems),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'View more ${order.items.length - 1} item${order.items.length > 2 ? 's' : ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kDustyRose,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _kDustyRose,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Additional products (when expanded)
              const Divider(height: 1, thickness: 0.6, color: _kBorder, indent: 16, endIndent: 16),
              ...order.items.skip(1).map((item) {
                return _ProductItemRow(item: item, showPrice: true);
              }),

              // View less button (when expanded)
              InkWell(
                onTap: () => setState(() => _expandedItems = !_expandedItems),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'View less',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kDustyRose,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _kDustyRose,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Total price summary row for multi-item order
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${order.items.length} items)',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                    ),
                  ),
                  Text(
                    '₱${totalToShow.toStringAsFixed(2)}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kDeepRose,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons footer
          Builder(
            builder: (context) {
              final canCancel = order.canCancel;
              final canBuyAgain = order.status == 'delivered' || order.status == 'completed';
              final canRate = (order.status == 'delivered' || order.status == 'completed') && !_isFullyRated;
              final canComplete = order.status == 'delivered';
              final hasActions = canCancel || canBuyAgain || canRate || canComplete;

              if (!hasActions) return const SizedBox(height: 6);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(
                  mainAxisAlignment: canCancel ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    if (canCancel)
                      Expanded(
                        child: _buildCancelButton(),
                      ),
                    if (canCancel && (canBuyAgain || canRate || canComplete))
                      const SizedBox(width: 12),
                    if (canBuyAgain) ...[
                      canCancel
                          ? Expanded(child: _buildBuyAgainButton())
                          : _buildBuyAgainButton(),
                      if (!canCancel && (canRate || canComplete))
                        const SizedBox(width: 12),
                    ],
                    if (canRate) ...[
                      canCancel
                          ? Expanded(child: _buildRateButton())
                          : _buildRateButton(),
                      if (!canCancel && canComplete)
                        const SizedBox(width: 12),
                    ],
                    if (canComplete)
                      (canCancel
                          ? Expanded(child: _buildCompleteButton())
                          : _buildCompleteButton()),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE5A8B8), width: 1.1),
      ),
      child: InkWell(
        onTap: _cancelOrderFromCard,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Text(
            'Cancel Order',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC94343),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyAgainButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _kDustyRose, width: 1.1),
      ),
      child: InkWell(
        onTap: _buyAgainBusy ? null : _buyAgain,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: _buyAgainBusy
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kDeepRose,
                  ),
                )
              : Text(
                  'Buy Again',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    color: _kDeepRose,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRateButton() {
    return Material(
      color: _kDeepRose,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 1.2,
      shadowColor: _kDeepRose.withValues(alpha: 0.25),
      child: InkWell(
        onTap: _openOrderForRating,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            'Rate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Material(
      color: _kDeepRose,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 1.2,
      shadowColor: _kDeepRose.withValues(alpha: 0.25),
      child: InkWell(
        onTap: _markAsCompletedFromCard,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            'Complete',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
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
      if (mounted) {
        setState(() {});
      }
      await widget.onOrderUpdated?.call();
    }
  }
}

class _ProductItemRow extends StatelessWidget {
  final OrderItem item;
  final bool showPrice;
  final double? priceOverride;

  const _ProductItemRow({
    required this.item,
    this.showPrice = true,
    this.priceOverride,
  });

  @override
  Widget build(BuildContext context) {
    final price = priceOverride ?? item.lineTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image (74x74 rounded)
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _kSoftBlush,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _ImagePlaceholder(useEfloraLogo: item.isCustomOrder),
                      errorWidget: (_, __, ___) =>
                          _ImagePlaceholder(useEfloraLogo: item.isCustomOrder),
                    ),
                  )
                : _ImagePlaceholder(useEfloraLogo: item.isCustomOrder),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kTextCharcoal,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (item.rating != null && item.rating! >= 1) ...[
                      const SizedBox(width: 6),
                      _ItemRatingStars(rating: item.rating!),
                    ],
                  ],
                ),
                if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Variant: ${item.variantName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kDustyRose,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _kMuted,
                  ),
                ),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...item.addons.take(2).map(
                    (a) => Text(
                      '+ ${a.name}${a.quantity > 1 ? ' ×${a.quantity}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _kMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (showPrice) ...[
            const SizedBox(width: 8),
            Text(
              '₱${price.toStringAsFixed(2)}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: _kDeepRose,
              ),
            ),
          ],
        ],
      ),
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
          size: 14,
          color: filled ? const Color(0xFFF4A91F) : const Color(0x382C2520),
        );
      }),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.useEfloraLogo = false});

  final bool useEfloraLogo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _kSoftBlush,
        borderRadius: BorderRadius.all(Radius.circular(13)),
      ),
      child: Center(
        child: useEfloraLogo
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
              )
            : const Icon(
                Icons.local_florist_rounded,
                size: 26,
                color: Color(0x4DB5445A),
              ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C502846),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with store name and status pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kDeepRose,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pending payment • ${group.items.length} ${group.items.length == 1 ? 'item' : 'items'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _StatusPill(
                  label: 'TO PAY',
                  statusKey: 'pending',
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.6, color: _kBorder, indent: 16, endIndent: 16),

          // First product card
          if (group.items.isNotEmpty)
            _CartProductRow(
              item: group.items.first,
              showPrice: !hasMultipleItems,
            ),

          // Expandable additional items
          if (hasMultipleItems) ...[
            if (!_expanded) ...[
              InkWell(
                onTap: () => setState(() => _expanded = true),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'View more ${group.items.length - 1} item${group.items.length > 2 ? 's' : ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kDustyRose,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _kDustyRose,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Divider(height: 1, thickness: 0.6, color: _kBorder, indent: 16, endIndent: 16),
              ...group.items.skip(1).map((item) => _CartProductRow(item: item, showPrice: false)),
              InkWell(
                onTap: () => setState(() => _expanded = false),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'View less',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kDustyRose,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _kDustyRose,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          // Footer with subtotal and Pay Now action button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _kMuted,
                        ),
                      ),
                      Text(
                        '₱${group.subtotal.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _kDeepRose,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: _kDeepRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  elevation: 1.5,
                  shadowColor: _kDeepRose.withValues(alpha: 0.25),
                  child: InkWell(
                    onTap: _openCheckout,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      child: Text(
                        'Pay Now',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

class _CartProductRow extends StatelessWidget {
  final CartItem item;
  final bool showPrice;

  const _CartProductRow({
    required this.item,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = item.imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _kSoftBlush,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: imgUrl != null && imgUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextCharcoal,
                    height: 1.25,
                  ),
                ),
                if (item.variant != null && item.variant!.name.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Variant: ${item.variant!.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kDustyRose,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _kMuted,
                  ),
                ),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...item.addons.take(2).map(
                    (a) => Text(
                      '+ ${a.name}${a.quantity > 1 ? ' ×${a.quantity}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _kMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showPrice) ...[
            const SizedBox(width: 8),
            Text(
              '₱${item.subtotal.toStringAsFixed(2)}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _kDeepRose,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

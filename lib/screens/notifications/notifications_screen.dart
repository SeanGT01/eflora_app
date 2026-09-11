import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../utils/datetime_ph.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_confirm_dialog.dart';
import '../../widgets/glass.dart';
import '../orders/order_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};
  String _filter = 'all'; // 'all', 'unread', 'orders'
  bool _openingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().load();
        context.read<NotificationProvider>().setLiveMode(true);
      }
    });
  }

  @override
  void dispose() {
    // Revert back to normal polling frequency when leaving notifications screen
    try {
      context.read<NotificationProvider>().setLiveMode(false);
    } catch (_) {}
    super.dispose();
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelectItem(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final n in notifications) {
          final id = n['id'];
          if (id is int) _selectedIds.add(id);
        }
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await CustomConfirmDialog.show(
      context,
      title: 'Delete Notifications',
      message: 'Are you sure you want to delete $count selected notification${count > 1 ? 's' : ''}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirm == true && mounted) {
      final ids = _selectedIds.toList();
      setState(() {
        _selectedIds.clear();
        _isSelecting = false;
      });
      final ok = await context.read<NotificationProvider>().deleteSelected(ids);
      if (mounted) {
        showToast(
          context,
          ok
              ? '$count notification${count > 1 ? 's' : ''} deleted'
              : 'Failed to delete notifications',
        );
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final notifProv = context.read<NotificationProvider>();
    if (notifProv.notifications.isEmpty) return;

    final confirm = await CustomConfirmDialog.show(
      context,
      title: 'Delete All Messages',
      message: 'Are you sure you want to delete all notifications? This action cannot be undone.',
      confirmText: 'Delete All',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirm == true && mounted) {
      setState(() {
        _selectedIds.clear();
        _isSelecting = false;
      });
      final ok = await notifProv.deleteAll();
      if (mounted) {
        showToast(
          context,
          ok ? 'All notifications deleted' : 'Failed to delete notifications',
        );
      }
    }
  }

  Future<void> _deleteSingle(int id) async {
    final ok = await context.read<NotificationProvider>().deleteNotification(id);
    if (mounted && ok) {
      showToast(context, 'Notification removed');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> n) async {
    final id = n['id'] as int? ?? 0;
    final isRead = n['is_read'] == true;
    if (!isRead) {
      context.read<NotificationProvider>().markRead(id);
    }

    final refId = n['reference_id'] as int?;
    final type = (n['type'] as String? ?? '').toLowerCase();
    final title = (n['title'] as String? ?? '').toLowerCase();
    final isOrderRelated = type.contains('order') ||
        title.contains('order') ||
        type.contains('delivery') ||
        type.contains('transit') ||
        refId != null;

    if (isOrderRelated && refId != null && refId > 0 && !_openingOrder) {
      setState(() => _openingOrder = true);
      try {
        final res = await ApiService.getOrder(refId);
        if (mounted && res.isSuccess && res.data is Map) {
          final order = Order.fromJson(Map<String, dynamic>.from(res.data as Map));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: order),
            ),
          );
        }
      } catch (_) {
        // Silently handle if order details cannot be loaded
      } finally {
        if (mounted) {
          setState(() => _openingOrder = false);
        }
      }
    }
  }

  bool _isOrderNotification(Map<String, dynamic> n) {
    final type = (n['type'] as String? ?? '').toLowerCase();
    final title = (n['title'] as String? ?? '').toLowerCase();
    final msg = (n['message'] as String? ?? '').toLowerCase();
    return type.contains('order') ||
        title.contains('order') ||
        msg.contains('order') ||
        n['reference_id'] != null;
  }

  List<Map<String, dynamic>> _filterNotifications(
    List<Map<String, dynamic>> all,
  ) {
    if (_filter == 'unread') {
      return all.where((n) => n['is_read'] != true).toList();
    }
    if (_filter == 'orders') {
      return all.where(_isOrderNotification).toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();
    final notifications = notifProv.notifications;
    final unread = notifProv.unreadCount;
    final loading = notifProv.loading;

    final filtered = _filterNotifications(notifications);
    final allSelected =
        filtered.isNotEmpty && _selectedIds.length == filtered.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Text(
            _isSelecting ? '${_selectedIds.length} Selected' : 'Notifications',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
              letterSpacing: 0.3,
            ),
          ),
          leading: _isSelecting
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: AppColors.charcoal,
                  ),
                  onPressed: _toggleSelectMode,
                )
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.charcoal,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
          actions: [
            if (!_isSelecting) ...[
              if (unread > 0)
                TextButton(
                  onPressed: () async {
                    await notifProv.markAllRead();
                    if (context.mounted) {
                      showToast(context, 'All marked as read');
                    }
                  },
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.roseCta,
                    ),
                  ),
                ),
              if (notifications.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.charcoal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: const Color(0x2E2A231E),
                  onSelected: (val) {
                    if (val == 'select') {
                      _toggleSelectMode();
                    } else if (val == 'delete_all') {
                      _confirmDeleteAll();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'select',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.checklist_rounded,
                            size: 18,
                            color: AppColors.charcoal,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Select Messages',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Delete All',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ] else ...[
              TextButton(
                onPressed: () => _toggleSelectAll(filtered),
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.roseCta,
                  ),
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (!_isSelecting && notifications.isNotEmpty)
                _buildStatusChipRow(notifications, unread),
              Expanded(
                child: loading && notifications.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.roseCta,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.roseCta,
                        onRefresh: () => notifProv.load(silent: true),
                        child: filtered.isEmpty
                            ? _buildEmpty()
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  _isSelecting ? 100 : 28,
                                ),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final n = filtered[i];
                                  final id = n['id'] as int? ?? 0;
                                  final isSelected = _selectedIds.contains(id);

                                  if (_isSelecting) {
                                    return _buildSelectionItem(n, isSelected);
                                  }

                                  return Dismissible(
                                    key: ValueKey('notif_$id'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE57373),
                                            AppColors.error,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.lg,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onDismissed: (_) => _deleteSingle(id),
                                    child: _buildItem(n),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _isSelecting && filtered.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GlassCard(
                    radius: AppRadius.xl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shadows: AppShadows.glassRaised,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _toggleSelectAll(filtered),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    allSelected
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    color: AppColors.roseCta,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    allSelected
                                        ? 'Deselect All'
                                        : 'Select All (${filtered.length})',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _selectedIds.isNotEmpty
                                ? AppColors.error
                                : AppColors.muted.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            elevation: 0,
                          ),
                          onPressed: _selectedIds.isNotEmpty
                              ? _confirmDeleteSelected
                              : null,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Delete (${_selectedIds.length})',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildStatusChipRow(
    List<Map<String, dynamic>> allNotifications,
    int unreadCount,
  ) {
    final orderCount = allNotifications.where(_isOrderNotification).length;
    final tabs = [
      {'id': 'all', 'label': 'All', 'count': allNotifications.length},
      {'id': 'unread', 'label': 'Unread', 'count': unreadCount},
      {'id': 'orders', 'label': 'Orders', 'count': orderCount},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 10),
              for (final tab in tabs)
                _NotificationStatusTab(
                  label: tab['label'] as String,
                  count: tab['count'] as int,
                  selected: _filter == tab['id'],
                  onTap: () {
                    setState(() {
                      _filter = tab['id'] as String;
                      _selectedIds.clear();
                    });
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.6, color: Color(0x1A2C2520)),
      ],
    );
  }

  Widget _buildEmpty() {
    final isFiltered = _filter != 'all';
    String title = 'No notifications yet';
    String subtitle =
        'Updates about your orders, deliveries, and account will appear here.';

    if (_filter == 'unread') {
      title = 'All caught up!';
      subtitle = 'You have no unread notifications right now.';
    } else if (_filter == 'orders') {
      title = 'No order updates';
      subtitle = 'Order and delivery status notifications will appear here.';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.deepRose.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.glassBorder, width: 1.5),
                    boxShadow: AppShadows.petal,
                  ),
                  child: Center(
                    child: Icon(
                      _filter == 'unread'
                          ? Icons.done_all_rounded
                          : Icons.notifications_none_rounded,
                      size: 38,
                      color: AppColors.deepRose,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                if (isFiltered) ...[
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () => setState(() => _filter = 'all'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('View all notifications'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.roseCta,
                      textStyle: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  (IconData, Color) _getIconInfo(String type, String title, String message) {
    final text = '$type $title $message'.toLowerCase();
    if (text.contains('delivered') || text.contains('completed')) {
      return (Icons.check_circle_rounded, AppColors.sage);
    } else if (text.contains('transit') ||
        text.contains('on the way') ||
        text.contains('on_delivery')) {
      return (Icons.local_shipping_rounded, AppColors.deepRose);
    } else if (text.contains('ready') || text.contains('done_preparing')) {
      return (Icons.storefront_rounded, const Color(0xFF2980B9));
    } else if (text.contains('preparing')) {
      return (Icons.inventory_2_rounded, const Color(0xFFE67E22));
    } else if (text.contains('cancelled') || text.contains('rejected')) {
      return (Icons.cancel_rounded, const Color(0xFFC0392B));
    } else if (text.contains('refunded')) {
      return (Icons.currency_exchange_rounded, const Color(0xFF8E44AD));
    } else if (text.contains('confirmed') ||
        text.contains('accepted') ||
        text.contains('order')) {
      return (Icons.receipt_long_rounded, AppColors.deepRose);
    }
    return (Icons.notifications_outlined, AppColors.deepRose);
  }

  Widget _buildSelectionItem(Map<String, dynamic> n, bool isSelected) {
    final id = n['id'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        radius: AppRadius.lg,
        borderColor: isSelected
            ? AppColors.roseCta
            : AppColors.glassBorder,
        fill: isSelected
            ? AppColors.blush.withValues(alpha: 0.22)
            : null,
        onTap: () => _toggleSelectItem(id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.roseCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (_) => _toggleSelectItem(id),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildItemContent(n)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final isRead = n['is_read'] == true;
    final id = n['id'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: AppRadius.lg,
        tinted: !isRead, // Signature subtle pink/lavender wash when unread
        borderColor: isRead
            ? AppColors.glassBorder
            : AppColors.deepRose.withValues(alpha: 0.32),
        shadows: !isRead ? AppShadows.glassRaised : AppShadows.glass,
        onTap: () => _handleNotificationTap(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItemContent(n)),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: AppColors.muted.withValues(alpha: 0.7),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              elevation: 4,
              shadowColor: const Color(0x2E2A231E),
              onSelected: (val) {
                if (val == 'read') {
                  context.read<NotificationProvider>().markRead(id);
                } else if (val == 'delete') {
                  _deleteSingle(id);
                }
              },
              itemBuilder: (ctx) => [
                if (!isRead)
                  PopupMenuItem(
                    value: 'read',
                    child: Text(
                      'Mark as read',
                      style: GoogleFonts.dmSans(fontSize: 12.5),
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemContent(Map<String, dynamic> n) {
    final isRead = n['is_read'] == true;
    final type = n['type'] ?? '';
    final title = n['title'] ?? 'Notification';
    final message = n['message'] ?? '';
    final (icon, iconColor) = _getIconInfo(type, title, message);
    final refId = n['reference_id'] as int?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: AppColors.roseCta,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.roseCta.withValues(alpha: 0.45),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: isRead
                      ? AppColors.charcoal.withValues(alpha: 0.72)
                      : AppColors.charcoal,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11.5,
                    color: AppColors.muted.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(n['created_at']),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (refId != null && refId > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColors.borderStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Order #$refId',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.deepRose,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.deepRose,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = parseBackendDateTime(iso)?.toLocal();
      if (dt == null) return '';
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _NotificationStatusTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _NotificationStatusTab({
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
                    top: 6,
                    right: showBadge ? 14 : 0,
                    bottom: 8,
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.roseCta : AppColors.muted,
                      height: 1.1,
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 1,
                    right: -2,
                    child: _StatusBadge(count: count),
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

class _StatusBadge extends StatelessWidget {
  final int count;

  const _StatusBadge({required this.count});

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

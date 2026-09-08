import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../utils/datetime_ph.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Notifications', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete $count selected notification${count > 1 ? 's' : ''}?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: AppColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
          ok ? '$count notification${count > 1 ? 's' : ''} deleted' : 'Failed to delete notifications',
        );
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final notifProv = context.read<NotificationProvider>();
    if (notifProv.notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete All Messages', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete all notifications? This cannot be undone.',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: AppColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete All', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();
    final notifications = notifProv.notifications;
    final unread = notifProv.unreadCount;
    final loading = notifProv.loading;
    final allSelected = notifications.isNotEmpty && _selectedIds.length == notifications.length;

    return Scaffold(
      backgroundColor: AppColors.pageCream,
      appBar: AppBar(
        title: Text(
          _isSelecting
              ? '${_selectedIds.length} Selected'
              : 'Notifications',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.charcoal),
                onPressed: _toggleSelectMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.charcoal),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose,
                  ),
                ),
              ),
            if (notifications.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.charcoal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        const Icon(Icons.checklist_rounded, size: 18, color: AppColors.charcoal),
                        const SizedBox(width: 10),
                        Text('Select Messages', style: GoogleFonts.dmSans(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('Delete All', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
          ] else ...[
            TextButton(
              onPressed: () => _toggleSelectAll(notifications),
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepRose,
                ),
              ),
            ),
          ],
        ],
      ),
      body: loading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose))
          : RefreshIndicator(
              color: AppColors.deepRose,
              onRefresh: () => notifProv.load(silent: true),
              child: notifications.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        _isSelecting ? 90 : 24,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final n = notifications[i];
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
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          ),
                          onDismissed: (_) => _deleteSingle(id),
                          child: _buildItem(n),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: _isSelecting && notifications.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(
                          allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          color: AppColors.deepRose,
                          size: 20,
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All (${notifications.length})',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                        onPressed: () => _toggleSelectAll(notifications),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _selectedIds.isNotEmpty ? AppColors.error : AppColors.muted.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      onPressed: _selectedIds.isNotEmpty ? _confirmDeleteSelected : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        'Delete (${_selectedIds.length})',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.deepRose.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: AppColors.deepRose,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates about your orders and account will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
            ),
          ]),
        ),
      ],
    );
  }

  (IconData, Color) _getIconInfo(String type, String title, String message) {
    final text = '$type $title $message'.toLowerCase();
    if (text.contains('delivered') || text.contains('completed')) {
      return (Icons.check_circle_rounded, AppColors.sage);
    } else if (text.contains('transit') || text.contains('on the way') || text.contains('on_delivery')) {
      return (Icons.local_shipping_rounded, AppColors.deepRose);
    } else if (text.contains('ready') || text.contains('done_preparing')) {
      return (Icons.storefront_rounded, const Color(0xFF2980B9));
    } else if (text.contains('preparing')) {
      return (Icons.inventory_2_rounded, const Color(0xFFE67E22));
    } else if (text.contains('cancelled') || text.contains('rejected')) {
      return (Icons.cancel_rounded, const Color(0xFFC0392B));
    } else if (text.contains('refunded')) {
      return (Icons.currency_exchange_rounded, const Color(0xFF8E44AD));
    } else if (text.contains('confirmed') || text.contains('accepted') || text.contains('order')) {
      return (Icons.receipt_long_rounded, AppColors.deepRose);
    }
    return (Icons.notifications_outlined, AppColors.deepRose);
  }

  Widget _buildSelectionItem(Map<String, dynamic> n, bool isSelected) {
    final id = n['id'] as int? ?? 0;
    return InkWell(
      onTap: () => _toggleSelectItem(id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepRose.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.deepRose : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.deepRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

    return InkWell(
      onTap: () {
        if (!isRead) {
          context.read<NotificationProvider>().markRead(id);
        }
      },
      onLongPress: () {
        setState(() {
          _isSelecting = true;
          _selectedIds.add(id);
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.deepRose.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.deepRose.withValues(alpha: 0.25),
            width: isRead ? 1 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItemContent(n)),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, size: 18, color: AppColors.muted.withValues(alpha: 0.6)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    child: Text('Mark as read', style: GoogleFonts.dmSans(fontSize: 12)),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error)),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
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
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.deepRose,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: isRead ? AppColors.charcoal.withValues(alpha: 0.75) : AppColors.charcoal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(n['created_at']),
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  color: AppColors.muted.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getNotifications();
    if (result.isSuccess && result.data is Map) {
      final list = (result.data as Map)['notifications'] as List? ?? [];
      setState(() {
        _notifications = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
    });
  }

  Future<void> _markRead(int id) async {
    await ApiService.markNotificationRead(id);
    setState(() {
      final n = _notifications.firstWhere((e) => e['id'] == id, orElse: () => {});
      if (n.isNotEmpty) n['is_read'] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.deepRose)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose))
          : RefreshIndicator(
              color: AppColors.deepRose,
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildItem(_notifications[i]),
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(children: [
            Icon(Icons.notifications_none_outlined, size: 48, color: AppColors.muted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('No notifications yet', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted)),
          ]),
        ),
      ],
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final isRead = n['is_read'] == true;
    final type = n['type'] ?? '';

    IconData icon;
    Color iconColor;
    if (type.contains('approved')) {
      icon = Icons.check_circle_outline;
      iconColor = AppColors.sage;
    } else if (type.contains('rejected')) {
      icon = Icons.cancel_outlined;
      iconColor = const Color(0xFFc0392b);
    } else {
      icon = Icons.notifications_outlined;
      iconColor = AppColors.deepRose;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) _markRead(n['id']);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.warmWhite : AppColors.deepRose.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? AppColors.border : AppColors.deepRose.withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    n['title'] ?? 'Notification',
                    style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppColors.deepRose, shape: BoxShape.circle),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                n['message'] ?? '',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(n['created_at']),
                style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted.withOpacity(0.7)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso ?? '';
    }
  }
}

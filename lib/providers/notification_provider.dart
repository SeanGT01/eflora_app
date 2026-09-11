import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  Timer? _pollTimer;
  bool _liveMode = false;
  bool _fetching = false;

  NotificationProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load(silent: true);
    }
  }

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get hasUnread => _unreadCount > 0;

  void startPolling() {
    if (_pollTimer != null) return;
    load(silent: true);
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _pollTimer?.cancel();
    final interval = _liveMode
        ? const Duration(seconds: 3)
        : const Duration(seconds: 6);
    _pollTimer = Timer.periodic(interval, (_) => load(silent: true));
  }

  void setLiveMode(bool enabled) {
    if (_liveMode == enabled) return;
    _liveMode = enabled;
    if (_pollTimer != null) {
      _scheduleTimer();
    }
    if (enabled) {
      load(silent: true);
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent && _notifications.isEmpty) {
      _loading = true;
      notifyListeners();
    }

    try {
      final res = await ApiService.getNotifications();
      if (res.isSuccess && res.data is Map) {
        final map = res.data as Map<String, dynamic>;
        final list = map['notifications'] as List? ?? [];
        final parsed = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final newCount = (map['unread_count'] as num?)?.toInt() ??
            parsed.where((n) => n['is_read'] != true).length;

        final hasChanged = newCount != _unreadCount ||
            _isDifferent(parsed, _notifications);

        if (hasChanged) {
          _notifications = parsed;
          _unreadCount = newCount;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load notifications: $e');
    } finally {
      _fetching = false;
      if (!silent && _loading) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  bool _isDifferent(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] || a[i]['is_read'] != b[i]['is_read']) {
        return true;
      }
    }
    return false;
  }

  Future<void> markRead(int id) async {
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1) {
      final wasRead = _notifications[idx]['is_read'] == true;
      if (!wasRead) {
        _notifications[idx]['is_read'] = true;
        _unreadCount = max(0, _unreadCount - 1);
        notifyListeners();
        await ApiService.markNotificationRead(id);
      }
    }
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0 && _notifications.every((n) => n['is_read'] == true)) {
      return;
    }
    for (var n in _notifications) {
      n['is_read'] = true;
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await ApiService.markAllNotificationsRead();
    } catch (e) {
      debugPrint('❌ Error marking all notifications read: $e');
    }
  }

  Future<bool> deleteNotification(int id) async {
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1) {
      final wasUnread = _notifications[idx]['is_read'] != true;
      _notifications.removeAt(idx);
      if (wasUnread) {
        _unreadCount = max(0, _unreadCount - 1);
      }
      notifyListeners();

      final res = await ApiService.deleteNotification(id);
      return res.isSuccess;
    }
    return false;
  }

  Future<bool> deleteSelected(List<int> ids) async {
    if (ids.isEmpty) return true;
    final set = ids.toSet();
    _notifications.removeWhere((n) => set.contains(n['id']));
    _unreadCount = _notifications.where((n) => n['is_read'] != true).length;
    notifyListeners();

    final res = await ApiService.deleteNotifications(ids: ids);
    return res.isSuccess;
  }

  Future<bool> deleteAll() async {
    if (_notifications.isEmpty) return true;
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();

    final res = await ApiService.deleteNotifications(all: true);
    return res.isSuccess;
  }

  void reset() {
    stopPolling();
    if (_notifications.isEmpty && _unreadCount == 0 && !_loading) return;
    _notifications = [];
    _unreadCount = 0;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    super.dispose();
  }
}

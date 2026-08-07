import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/app_quality.dart';
import '../services/chat_service.dart';

/// Provider for chat state management.
/// Handles conversation list, unread counts, and polling.
class ChatProvider extends ChangeNotifier {
  List<ChatConversation> _conversations = [];
  int _totalUnread = 0;
  bool _loading = false;
  Timer? _unreadTimer;
  bool _liveMode = false;
  /// Conversations cleared locally — ignore stale unread polls until server catches up.
  final Set<int> _locallyReadIds = {};

  List<ChatConversation> get conversations => _conversations;
  int get totalUnread => _totalUnread;
  bool get loading => _loading;

  /// Start periodically polling for unread count.
  void startPolling() {
    if (_unreadTimer != null) return;
    _fetchUnread();
    _scheduleUnreadTimer();
  }

  void _scheduleUnreadTimer() {
    _unreadTimer?.cancel();
    final interval = _liveMode
        ? AppQuality.instance.chatLiveInterval
        : AppQuality.instance.chatUnreadInterval;
    _unreadTimer = Timer.periodic(interval, (_) => _fetchUnread());
  }

  /// Faster sync while chat UI is open (Messenger-style).
  void setLiveMode(bool enabled) {
    if (_liveMode == enabled) return;
    _liveMode = enabled;
    if (_unreadTimer != null) _scheduleUnreadTimer();
    if (enabled) _fetchUnread();
  }

  /// Stop polling.
  void stopPolling() {
    _unreadTimer?.cancel();
    _unreadTimer = null;
  }

  /// Clear local unread state (e.g. on logout).
  void clearUnread() {
    if (_totalUnread == 0 && _conversations.isEmpty && _locallyReadIds.isEmpty) return;
    _totalUnread = 0;
    _conversations = [];
    _locallyReadIds.clear();
    notifyListeners();
  }

  /// Stop polling and wipe local chat badge/state.
  void reset() {
    stopPolling();
    _liveMode = false;
    clearUnread();
  }

  /// Load conversations from server.
  Future<void> loadConversations() async {
    _loading = true;
    notifyListeners();

    _conversations = _applyLocalReadOverrides(await ChatService.getConversations());
    _loading = false;
    notifyListeners();
  }

  /// Quiet refresh used by live inbox sync.
  Future<void> refreshConversations() async {
    final raw = await ChatService.getConversations();
    // Only lift suppress when the *server* confirms unread is gone
    if (_locallyReadIds.isNotEmpty) {
      for (final id in _locallyReadIds.toList()) {
        final match = raw.where((c) => c.id == id);
        if (match.isNotEmpty && match.first.unreadCount == 0) {
          _locallyReadIds.remove(id);
        }
      }
    }
    final convos = _applyLocalReadOverrides(raw);
    _conversations = convos;
    final localTotal = convos.fold<int>(0, (sum, c) => sum + c.unreadCount);
    if (localTotal != _totalUnread) {
      _totalUnread = localTotal;
    }
    notifyListeners();
  }

  List<ChatConversation> _applyLocalReadOverrides(List<ChatConversation> list) {
    if (_locallyReadIds.isEmpty) return list;
    return list.map((c) {
      if (_locallyReadIds.contains(c.id) && c.unreadCount > 0) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();
  }

  /// Fetch total unread count.
  Future<void> _fetchUnread() async {
    final count = await ChatService.getUnreadCount();
    var next = count;
    // Never restore a badge we already cleared locally (stale in-flight polls)
    if (_locallyReadIds.isNotEmpty && count > _totalUnread) {
      next = _totalUnread;
    }
    if (next != _totalUnread) {
      _totalUnread = next;
      notifyListeners();
    }
  }

  /// Force refresh unread count (e.g., after reading messages).
  Future<void> refreshUnread() async => _fetchUnread();

  /// Align FAB badge with a known local inbox total (Messenger-style).
  void syncUnreadTotal(int total) {
    final next = total.clamp(0, 1 << 30);
    if (next == _totalUnread) return;
    _totalUnread = next;
    notifyListeners();
  }

  /// Instantly clear unread for a conversation and update FAB badge.
  void markConversationReadLocal(int conversationId, {int? knownUnread}) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    var cleared = knownUnread ?? 0;
    if (idx != -1) {
      final rowUnread = _conversations[idx].unreadCount;
      // Prefer the larger value so a stale provider row can't block badge clear
      if (rowUnread > cleared) cleared = rowUnread;
      if (rowUnread > 0) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      }
    }
    _locallyReadIds.add(conversationId);
    if (cleared > 0) {
      _totalUnread = (_totalUnread - cleared).clamp(0, 1 << 30);
      notifyListeners();
    } else {
      // Still notify so listeners re-read zeroed rows
      notifyListeners();
    }
  }

  /// Call after server mark-as-read succeeds so polls can fully reconcile.
  void confirmConversationRead(int conversationId) {
    _locallyReadIds.remove(conversationId);
  }

  /// Update inbox preview when a message is sent/received.
  void touchConversationPreview({
    required int conversationId,
    required String previewText,
    int? senderId,
  }) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final updated = _conversations[idx].copyWith(
      lastMessageText: previewText,
      lastMessageAt: DateTime.now().toUtc().toIso8601String(),
      lastSenderId: senderId,
      unreadCount: _conversations[idx].unreadCount,
    );
    _conversations.removeAt(idx);
    _conversations.insert(0, updated);
    notifyListeners();
  }

  /// Create or get conversation with a store and return it.
  Future<ChatConversation?> openConversation(int storeId) async {
    final convo = await ChatService.getOrCreateConversation(storeId);
    if (convo != null) {
      await loadConversations();
    }
    return convo;
  }

  /// Delete a conversation.
  Future<bool> deleteConversation(int convoId) async {
    final ok = await ChatService.deleteConversation(convoId);
    if (ok) {
      _conversations.removeWhere((c) => c.id == convoId);
      _locallyReadIds.remove(convoId);
      notifyListeners();
    }
    return ok;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

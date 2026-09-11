import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/app_quality.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/datetime_ph.dart';
import '../utils/responsive.dart';
import 'customer_default_avatar.dart';
import 'common.dart';
import 'chat_order_card.dart';
import 'chat_custom_ticket_card.dart';
import 'custom_ticket_checkout_sheet.dart';
import 'custom_confirm_dialog.dart';
import '../screens/main_shell.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/store/store_page.dart';

/// Lightweight Q&A message representation for Quick Answers.
class _QaMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;

  _QaMessage({
    required this.isUser,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ═══════════════════════════════════════════════════════════════════════
// FLOATING CHAT BUTTON — AssistiveTouch-style dockable FAB
// Drag right to morph into a sleek edge tab; tap the tab to expand again.
// A short tap (no meaningful drag) still opens chat.
// ═══════════════════════════════════════════════════════════════════════

class FloatingChatButton extends StatefulWidget {
  final VoidCallback onTap;

  /// Extra lift above the shell bottom nav. Defaults to the standard
  /// MainShell / RiderShell nav height (62) so the FAB is not buried
  /// under the tab bar when `extendBody: true`.
  final double bottomNavClearance;

  const FloatingChatButton({
    super.key,
    required this.onTap,
    this.bottomNavClearance = 62,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  static const double _expandedSize = 56;
  static const double _tabWidth = 38;
  static const double _tabHeight = 56;
  /// Tight to the trailing edge so it reads next to the Account tab.
  static const double _expandedRight = 14;
  static const double _dockedRight = 0;
  /// Breathing room between the FAB and the top of the bottom nav.
  static const double _gapAboveNav = 8;

  late final AnimationController _anim;

  /// 0 = fully expanded circle, 1 = docked edge tab.
  double _progress = 0;
  double _dragStartProgress = 0;
  bool _dragging = false;

  bool get _docked => _progress > 0.85;

  double get _right =>
      _expandedRight + (_dockedRight - _expandedRight) * _progress;

  double get _width => _expandedSize + (_tabWidth - _expandedSize) * _progress;

  double get _height =>
      _expandedSize + (_tabHeight - _expandedSize) * _progress;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double target) async {
    final start = _progress;
    _anim.stop();
    _anim.reset();
    void tick() {
      if (!mounted) return;
      setState(() {
        _progress = start +
            (target - start) * Curves.easeOutCubic.transform(_anim.value);
      });
    }

    _anim.addListener(tick);
    await _anim.forward();
    _anim.removeListener(tick);
    if (!mounted) return;
    setState(() => _progress = target);
  }

  void _expand() {
    HapticFeedback.selectionClick();
    _animateTo(0);
  }

  void _dock() {
    HapticFeedback.lightImpact();
    _animateTo(1);
  }

  void _onPanStart(DragStartDetails _) {
    _dragging = false;
    _dragStartProgress = _progress;
    _anim.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Finger right → increase dock progress.
    final next = (_progress + details.delta.dx / 80).clamp(0.0, 1.0);
    if ((next - _dragStartProgress).abs() > 0.06) _dragging = true;
    setState(() => _progress = next);
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldDock = velocity > 180 || _progress > 0.45;
    if (shouldDock) {
      _dock();
    } else {
      _expand();
    }
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _dragging = false;
    });
  }

  void _onTap() {
    if (_dragging) return;
    if (_docked) {
      _expand();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatProvider>().totalUnread;
    // viewPadding survives Scaffold's extendBody padding removal — padding.bottom
    // is often 0 in the body, which used to leave the FAB floating too high.
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final navHeight = context.s(widget.bottomNavClearance).clamp(56.0, 70.0);
    final bottom = safeBottom + navHeight + _gapAboveNav;
    final t = _progress;

    // Morph circle → right-edge tab (rounded on the left, flat on the right).
    final radius = BorderRadius.only(
      topLeft: Radius.circular(28),
      bottomLeft: Radius.circular(28),
      topRight: Radius.circular(28 * (1 - t)),
      bottomRight: Radius.circular(28 * (1 - t)),
    );

    return Positioned(
      bottom: bottom,
      right: _right,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: _onTap,
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Chat icon — shifts left slightly as the tab narrows.
              Align(
                alignment: Alignment(-0.15 * t, 0),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 24 - 2 * t,
                ),
              ),
              // Soft grip / expand hint on the flat edge while docking.
              if (t > 0.35)
                Positioned(
                  right: 5,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              if (unread > 0)
                Positioned(
                  top: -4,
                  left: t > 0.5 ? 0 : null,
                  right: t > 0.5 ? null : -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CHAT DRAWER — Messenger-style overlay with inbox + detail views
// ═══════════════════════════════════════════════════════════════════════

class ChatDrawer extends StatefulWidget {
  final VoidCallback onClose;

  /// Optionally open directly to a specific store conversation.
  final int? openStoreId;

  /// Optionally open directly to a specific customer conversation.
  final int? openCustomerId;

  /// Optional rider order context for creating/opening customer thread.
  final int? openOrderId;

  const ChatDrawer({
    super.key,
    required this.onClose,
    this.openStoreId,
    this.openCustomerId,
    this.openOrderId,
  });

  @override
  State<ChatDrawer> createState() => ChatDrawerState();
}

class ChatDrawerState extends State<ChatDrawer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ═══ VIEW STATE ═══
  bool _showDetail = false;
  ChatConversation? _activeConversation;
  double _lastBottomInset = 0.0;

  /// Kept separate from inbox rows so message/preview polls don't wipe it.
  ChatOrderContext? _orderContext;

  // ═══ INBOX ═══
  List<ChatConversation> _conversations = [];
  bool _inboxLoading = true;
  List<Map<String, dynamic>> _deliverableStores = [];
  bool _loadingDeliverableStores = false;

  // ═══ SEARCH ═══
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  bool _searching = false;
  Timer? _searchDebounce;

  // ═══ DETAIL / MESSAGES ═══
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  List<ChatMessage> _messages = [];
  bool _messagesLoading = true;
  bool _sending = false;
  bool _otherIsTyping = false;
  String? _typingName;
  bool _otherOnline = false;
  final Map<int, bool> _onlineByUserId = {};
  List<File> _pendingImages = [];
  ChatMessage? _replyingTo; // Track which message is being replied to
  late final ChatProvider _chatProvider;
  Timer? _pollTimer;
  Timer? _typingDebounce;
  Timer? _typingKeepAlive;
  Timer? _typingPollTimer;
  Timer? _onlinePollTimer;
  Timer? _inboxPresenceTimer;
  DateTime? _lastTypingPing;
  Timer? _inboxSyncTimer;
  bool _loadingInbox = false;
  bool _loadingMessages = false;
  bool _pollingTyping = false;
  bool _markingRead = false;
  int? _suggestOrderId;
  int? _suggestForConvoId;
  bool _orderSuggestDismissed = false;

  // ═══ QUICK ANSWERS & SUPPORT ═══
  bool _quickAnswersMode = false;
  List<SupportFaq> _supportFaqs = [];
  bool _loadingFaqs = false;
  final List<_QaMessage> _qaMessages = [];
  final ScrollController _qaScrollController = ScrollController();
  bool _openingSupport = false;

  int get _myId => context.read<AuthProvider>().user?.id ?? 0;

  // ═══ ANIMATION ═══
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatProvider = context.read<ChatProvider>();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
    _chatProvider.setLiveMode(true);

    final providerConvos = _chatProvider.conversations.isNotEmpty
        ? _chatProvider.conversations
        : ChatService.getCachedConversationsSync();
    if (providerConvos.isNotEmpty) {
      _conversations = List<ChatConversation>.from(providerConvos);
      _inboxLoading = false;
    } else {
      _loadLocalConversations();
    }

    final cachedDeliverable = ChatService.getCachedDeliverableStoresSync();
    if (cachedDeliverable.isNotEmpty) {
      _deliverableStores = cachedDeliverable;
    } else {
      _loadLocalDeliverableStores();
    }

    _loadInbox();
    _loadDeliverableStores();
    _startInboxSync();

    if (widget.openCustomerId != null ||
        widget.openStoreId != null ||
        widget.openOrderId != null) {
      _openWithContext();
    }
  }

  Future<void> _loadLocalConversations() async {
    final local = await ChatService.getLocalConversations();
    if (!mounted || local.isEmpty) return;
    if (_conversations.isEmpty) {
      setState(() {
        _conversations = local;
        _inboxLoading = false;
      });
    }
  }

  Future<void> _loadLocalDeliverableStores() async {
    final local = await ChatService.getLocalDeliverableStores();
    if (!mounted || local.isEmpty) return;
    if (_deliverableStores.isEmpty) {
      setState(() {
        _deliverableStores = local;
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > _lastBottomInset && _showDetail) {
      _scrollToBottom();
    }
    _lastBottomInset = bottomInset;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatProvider.setLiveMode(false);
    _slideController.dispose();
    _searchController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _qaScrollController.dispose();
    _pollTimer?.cancel();
    _typingDebounce?.cancel();
    _typingKeepAlive?.cancel();
    _typingPollTimer?.cancel();
    _onlinePollTimer?.cancel();
    _inboxPresenceTimer?.cancel();
    _searchDebounce?.cancel();
    _inboxSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _slideController.reverse();
    widget.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INBOX LOGIC
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadInbox() async {
    if (_loadingInbox) return;
    _loadingInbox = true;
    try {
      final convos = await ChatService.getConversations();
      if (!mounted) return;
      // Keep optimistic unread clears while server catches up, but only for threads explicitly read in this session or currently open
      final merged = convos.map((c) {
        final localIdx = _conversations.indexWhere((x) => x.id == c.id);
        final isCurrentlyOpen = _showDetail && _activeConversation?.id == c.id;
        final isLocallyRead = _chatProvider.isLocallyRead(c.id) || isCurrentlyOpen;

        var result = c;
        if (isLocallyRead && c.unreadCount > 0) {
          result = result.copyWith(unreadCount: 0);
        }

        // Prefer newer local preview if timestamps look equal/older (just sent)
        if (localIdx != -1) {
          final local = _conversations[localIdx];
          final localAt = local.lastMessageAt;
          final serverAt = c.lastMessageAt;
          if (localAt != null &&
              localAt.isNotEmpty &&
              (serverAt == null ||
                  serverAt.isEmpty ||
                  localAt.compareTo(serverAt) >= 0) &&
              local.lastMessageText != null &&
              local.lastMessageText != c.lastMessageText) {
            result = result.copyWith(
              lastMessageText: local.lastMessageText,
              lastMessageAt: localAt,
              lastSenderId: local.lastSenderId,
              unreadCount: isLocallyRead ? 0 : c.unreadCount,
            );
          }
        }
        return result;
      }).toList();

      // If active conversation is open (e.g. rider thread opened from order details),
      // ensure it is retained at the top of the inbox list even if server sync is still pending.
      if (_activeConversation != null &&
          !merged.any((c) => c.id == _activeConversation!.id)) {
        merged.insert(0, _activeConversation!);
      }

      setState(() {
        _conversations = merged;
        _inboxLoading = false;
      });
      final total = merged.fold<int>(0, (sum, c) => sum + c.unreadCount);
      _chatProvider.syncUnreadTotal(total);
      _chatProvider.refreshUnread();
      if (!_showDetail) {
        await _refreshInboxPresence();
        _startInboxPresencePoll();
      }
    } finally {
      _loadingInbox = false;
    }
  }

  Future<void> _loadDeliverableStores() async {
    final role = context.read<AuthProvider>().user?.role;
    if (role != 'customer' || _loadingDeliverableStores) return;
    _loadingDeliverableStores = true;
    try {
      final stores = await ChatService.getDeliverableStores();
      if (!mounted) return;
      setState(() {
        _deliverableStores = stores;
      });
    } catch (_) {
      // Quiet fail fallback
    } finally {
      _loadingDeliverableStores = false;
    }
  }

  Future<void> _refreshInboxPresence() async {
    final ids = _conversations
        .map((c) => c.otherUser?.id)
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return;
    final map = await ChatService.getPresenceStatus(ids);
    if (!mounted || map.isEmpty) return;
    setState(() {
      _onlineByUserId.addAll(map);
    });
  }

  void _startInboxPresencePoll() {
    _inboxPresenceTimer?.cancel();
    _inboxPresenceTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _showDetail) return;
      await _refreshInboxPresence();
    });
  }

  void _stopInboxPresencePoll() {
    _inboxPresenceTimer?.cancel();
    _inboxPresenceTimer = null;
  }

  bool _isPartnerOnline(int? userId) {
    if (userId == null || userId <= 0) return false;
    return _onlineByUserId[userId] == true;
  }

  void _startInboxSync() {
    _inboxSyncTimer?.cancel();
    _inboxSyncTimer =
        Timer.periodic(AppQuality.instance.chatInboxSyncInterval, (_) async {
      if (!mounted || _showDetail) return;
      await _loadInbox();
    });
  }

  void _applyLocalRead(int conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    final cleared = idx != -1 ? _conversations[idx].unreadCount : 0;
    if (idx != -1 && cleared > 0) {
      setState(() {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      });
    }
    _chatProvider.markConversationReadLocal(conversationId,
        knownUnread: cleared > 0 ? cleared : null);
  }

  void _applyLocalPreview(int conversationId, String preview, {int? senderId}) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      setState(() {
        final updated = _conversations[idx].copyWith(
          lastMessageText: preview,
          lastMessageAt: DateTime.now().toUtc().toIso8601String(),
          lastSenderId: senderId,
        );
        _conversations.removeAt(idx);
        _conversations.insert(0, updated);
        if (_activeConversation?.id == conversationId) {
          // Inbox rows don't carry order_context — keep the active thread's.
          _activeConversation = updated.copyWith(
            orderContext: _orderContext ??
                _activeConversation!.orderContext ??
                updated.orderContext,
            isRiderThread: _activeConversation!.isRiderThread ||
                updated.isRiderThread ||
                _orderContext != null,
          );
        }
      });
    } else if (_activeConversation != null &&
        _activeConversation!.id == conversationId) {
      setState(() {
        final updated = _activeConversation!.copyWith(
          lastMessageText: preview,
          lastMessageAt: DateTime.now().toUtc().toIso8601String(),
          lastSenderId: senderId,
        );
        _conversations.insert(0, updated);
        _activeConversation = updated;
      });
    }
    _chatProvider.touchConversationPreview(
      conversationId: conversationId,
      previewText: preview,
      senderId: senderId,
      conversation: _activeConversation,
    );
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ChatService.searchStores(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = true;
          _searching = false;
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OPEN CONVERSATION
  // ═══════════════════════════════════════════════════════════════════════

  void _openConversation(ChatConversation convo) {
    _stopPoll();
    _stopInboxPresencePoll();
    _chatProvider.setLiveMode(false);
    if (convo.id != _suggestForConvoId) {
      _suggestOrderId = null;
    }
    final existingIdx = _conversations.indexWhere((c) => c.id == convo.id);
    if (existingIdx == -1) {
      _conversations.insert(0, convo);
    } else {
      _conversations[existingIdx] = convo;
    }
    _chatProvider.upsertConversation(convo);

    final cached = ChatService.getCachedMessagesSync(convo.id);
    final hasCached = cached.isNotEmpty;

    setState(() {
      _showDetail = true;
      _quickAnswersMode = false;
      _activeConversation = convo;
      _orderContext = convo.orderContext;
      _messages = hasCached ? List<ChatMessage>.from(cached) : [];
      _messagesLoading = !hasCached;
      _pendingImages.clear();
      _otherIsTyping = false;
      _otherOnline = _isPartnerOnline(convo.otherUser?.id);
    });

    if (hasCached) {
      _scrollToBottom(immediate: true);
    } else {
      _loadLocalMessages(convo.id);
    }

    _loadMessages(forceScroll: true);
    _applyLocalRead(convo.id);
    _markRead();
    _checkOnline();
    _startPoll();
    _ensureOrderContext(convo);
  }

  Future<void> _loadLocalMessages(int convoId) async {
    final local = await ChatService.getLocalMessages(convoId);
    if (!mounted || _activeConversation?.id != convoId || local.isEmpty) return;
    if (_messagesLoading || _messages.isEmpty) {
      setState(() {
        _messages = local;
        _messagesLoading = false;
      });
      _scrollToBottom(immediate: true);
    }
  }

  ChatOrderContext _cardContextForMessage(ChatMessage msg) {
    if (msg.orderCard != null &&
        (msg.orderCard!.orderId > 0 || msg.orderCard!.items.isNotEmpty)) {
      return msg.orderCard!;
    }
    return const ChatOrderContext(
      orderId: 0,
      orderNumber: 'Order details',
      status: '',
    );
  }

  bool _threadHasOrderCard(int oid) {
    return _messages.any((m) {
      if (m.isDeleted) return false;
      if (m.messageType != 'order_card') return false;
      final id = m.orderCard?.orderId ?? 0;
      return id == oid;
    });
  }

  bool get _showOrderSuggest {
    if (_orderSuggestDismissed || _messagesLoading) return false;
    final oid = _suggestOrderId;
    if (oid == null || _activeConversation?.id != _suggestForConvoId) {
      return false;
    }
    return !_threadHasOrderCard(oid);
  }

  Future<void> _shareOrderCard() async {
    final convo = _activeConversation;
    final oid = _suggestOrderId;
    if (convo == null || oid == null) return;
    if (_threadHasOrderCard(oid)) {
      setState(() {
        _orderSuggestDismissed = true;
        _suggestOrderId = null;
      });
      return;
    }
    final msg = await ChatService.sendOrderCard(convo.id, oid);
    if (!mounted) return;
    if (msg == null) {
      showToast(context, 'Could not share order details', isError: true);
      return;
    }
    setState(() {
      if (!_messages.any((m) => m.id == msg.id)) {
        _messages.add(msg);
      }
      _orderSuggestDismissed = true;
      _suggestOrderId = null;
    });
    ChatService.appendMessageToCache(convo.id, msg);
    _applyLocalPreview(convo.id, msg.orderCardPreview, senderId: msg.senderId);
    _scrollToBottom();
  }

  Future<void> _ensureOrderContext(ChatConversation convo) async {
    final role = context.read<AuthProvider>().user?.role;
    final looksLikeRiderThread = convo.isRiderThread ||
        convo.orderContext != null ||
        _orderContext != null ||
        convo.otherUser?.role == 'rider' ||
        role == 'rider';
    if (!looksLikeRiderThread) return;

    final preferredId = widget.openOrderId;
    if (_orderContext != null &&
        (preferredId == null || preferredId == _orderContext!.orderId)) {
      return;
    }

    final enriched = await ChatService.getConversation(
      convo.id,
      orderId: preferredId,
    );
    if (!mounted || enriched == null) return;
    if (_activeConversation?.id != convo.id) return;
    if (enriched.orderContext == null) return;

    setState(() {
      _orderContext = enriched.orderContext;
      _activeConversation = (_activeConversation ?? enriched).copyWith(
        orderContext: enriched.orderContext,
        isRiderThread: true,
      );
    });
  }

  Future<void> _openWithStore(int storeId) async {
    final convo = await ChatService.getOrCreateConversation(storeId);
    if (convo != null && mounted) {
      _openConversation(convo);
    }
  }

  Future<void> _openWithContext() async {
    // Rider order context must resolve first to avoid accidentally opening
    // the store's seller conversation.
    if (widget.openOrderId != null) {
      final convo =
          await ChatService.getOrCreateRiderConversation(widget.openOrderId!);
      if (!mounted) return;
      if (convo != null) {
        _suggestOrderId = widget.openOrderId;
        _suggestForConvoId = convo.id;
        _orderSuggestDismissed = false;
        _openConversation(convo);
        return;
      }
      showToast(context, 'Could not open rider chat for this order.', isError: true);
      return;
    }

    final convos = await ChatService.getConversations();
    if (!mounted) return;

    final customerId = widget.openCustomerId;
    final storeId = widget.openStoreId;

    if (customerId != null) {
      ChatConversation? target;
      for (final c in convos) {
        final customerMatch = c.customerId == customerId;
        final storeMatch = storeId == null || c.storeId == storeId;
        if (customerMatch && storeMatch) {
          target = c;
          break;
        }
      }

      if (target != null) {
        setState(() {
          _conversations = convos;
          _inboxLoading = false;
        });
        _openConversation(target);
        return;
      }

      // If no context matched, keep drawer open on inbox.
      setState(() {
        _conversations = convos;
        _inboxLoading = false;
      });
      showToast(context, 'No existing conversation with this customer yet.', isError: true);
      return;
    }

    // Store-only context keeps previous behavior.
    if (storeId != null) {
      await _openWithStore(storeId);
    }
  }

  void _backToInbox() {
    _stopPoll();
    setState(() {
      _showDetail = false;
      _quickAnswersMode = false;
      _activeConversation = null;
      _orderContext = null;
      _messages = [];
      _pendingImages.clear();
    });
    // Local preview/unread already updated — paint immediately, reconcile in background
    _chatProvider.setLiveMode(true);
    _chatProvider.refreshUnread();
    _loadInbox();
    _startInboxPresencePoll();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MESSAGE LOGIC (same as ChatDetailScreen)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadMessages({bool forceScroll = false}) async {
    if (_activeConversation == null || _loadingMessages) return;
    _loadingMessages = true;
    try {
      final previousIds = _messages.map((m) => m.id).toSet();
      final nearBottom = !_scrollController.hasClients ||
          _scrollController.offset < 140;
      final msgs =
          await ChatService.getMessages(_activeConversation!.id, perPage: 50);
      if (!mounted) return;
      final hasNew = msgs.any((m) => !previousIds.contains(m.id));
      setState(() {
        _messages = msgs;
        _messagesLoading = false;
      });
      if (forceScroll || previousIds.isEmpty || (hasNew && nearBottom)) {
        _scrollToBottom(immediate: forceScroll || previousIds.isEmpty);
      }
      if (hasNew && msgs.isNotEmpty) {
        final last = msgs.last;
        final preview = last.messageType == 'image'
            ? (last.text?.isNotEmpty == true ? last.text! : '[Image]')
            : last.messageType == 'order_card'
                ? last.orderCardPreview
            : (last.text ?? '');
        _applyLocalPreview(_activeConversation!.id, preview,
            senderId: last.senderId);
        if (last.senderId != _myId) {
          _markRead();
        }
      }
    } finally {
      _loadingMessages = false;
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    void doScroll() {
      if (!mounted || !_scrollController.hasClients) return;
      if (immediate || _scrollController.offset > 400) {
        _scrollController.jumpTo(0.0);
      } else {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doScroll();
      // Double check in subsequent frame to lock at bottom (offset 0.0) after async image / card layout sizing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (immediate && _scrollController.offset != 0.0) {
          _scrollController.jumpTo(0.0);
        }
      });
    });
  }

  Future<void> _markRead() async {
    if (_activeConversation == null || _markingRead) return;
    _markingRead = true;
    try {
      final id = _activeConversation!.id;
      _applyLocalRead(id);
      final ok = await ChatService.markAsRead(id);
      if (!mounted) return;
      await _chatProvider.refreshUnread();
      if (ok) _chatProvider.confirmConversationRead(id);
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _checkOnline() async {
    if (_activeConversation == null) return;
    final convo = _activeConversation!;
    final otherId = convo.otherUser?.id ??
        (_myId == convo.customerId ? convo.sellerId : convo.customerId);
    if (otherId <= 0) return;
    final online = await ChatService.isUserOnline(otherId);
    if (mounted) {
      setState(() {
        _otherOnline = online;
        _onlineByUserId[otherId] = online;
      });
    }
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _onlinePollTimer?.cancel();
    _pollTimer =
        Timer.periodic(AppQuality.instance.chatMessagePollInterval, (_) async {
      await _loadMessages();
    });
    // Must stay under server typing TTL (~10s)
    _typingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollTyping();
    });
    _onlinePollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || !_showDetail || _activeConversation == null) return;
      _checkOnline();
    });
    _pollTyping();
    _checkOnline();
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _typingPollTimer?.cancel();
    _typingPollTimer = null;
    _onlinePollTimer?.cancel();
    _onlinePollTimer = null;
    _typingKeepAlive?.cancel();
    _typingKeepAlive = null;
  }

  Future<void> _pollTyping() async {
    if (_activeConversation == null || _pollingTyping) return;
    _pollingTyping = true;
    try {
      final typing = await ChatService.getTyping(_activeConversation!.id);
      if (!mounted) return;
      final nextTyping = typing.isNotEmpty;
      final nextName = nextTyping ? typing.first['full_name'] as String? : null;
      if (nextTyping == _otherIsTyping && nextName == _typingName) return;
      setState(() {
        _otherIsTyping = nextTyping;
        _typingName = nextName;
      });
    } finally {
      _pollingTyping = false;
    }
  }

  void _pingTyping() {
    if (_activeConversation == null) return;
    final now = DateTime.now();
    if (_lastTypingPing != null &&
        now.difference(_lastTypingPing!) < const Duration(milliseconds: 1800)) {
      return;
    }
    _lastTypingPing = now;
    ChatService.sendTyping(_activeConversation!.id);
  }

  void _onTextChanged(String text) {
    if (_activeConversation == null) return;
    if (text.trim().isEmpty) {
      _typingKeepAlive?.cancel();
      _typingKeepAlive = null;
      return;
    }
    _pingTyping();
    _typingDebounce?.cancel();
    _typingKeepAlive?.cancel();
    _typingKeepAlive = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_msgController.text.trim().isEmpty) {
        _typingKeepAlive?.cancel();
        _typingKeepAlive = null;
        return;
      }
      _pingTyping();
    });
    _typingDebounce = Timer(const Duration(seconds: 4), () {
      _typingKeepAlive?.cancel();
      _typingKeepAlive = null;
    });
  }

  Future<void> _sendText() async {
    if (_pendingImages.isNotEmpty) {
      await _confirmSendImages();
      return;
    }
    final text = _msgController.text.trim();
    if (text.isEmpty || _activeConversation == null) return;
    _msgController.clear();
    final replyId = _replyingTo?.id;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    HapticFeedback.lightImpact();

    final msg = await ChatService.sendMessage(_activeConversation!.id, text,
        replyToId: replyId);
    if (msg != null && mounted) {
      setState(() {
        _messages.add(msg);
        _sending = false;
      });
      ChatService.appendMessageToCache(_activeConversation!.id, msg);
      _applyLocalPreview(
        _activeConversation!.id,
        msg.text ?? text,
        senderId: msg.senderId,
      );
      _scrollToBottom();
    } else if (mounted) {
      setState(() {
        _sending = false;
        if (_msgController.text.isEmpty) _msgController.text = text;
      });
      showToast(context, 'Failed to send message. Please try again.', isError: true);
    }
  }

  Future<void> _pickImage() async {
    if (_pendingImages.length >= 5) {
      showToast(context, 'You can attach up to 5 images at a time.', isError: true);
      return;
    }
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pendingImages.add(File(picked.path)));
  }

  Future<void> _takePhoto() async {
    if (_pendingImages.length >= 5) {
      showToast(context, 'You can attach up to 5 images at a time.', isError: true);
      return;
    }
    final picked = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pendingImages.add(File(picked.path)));
  }

  void _cancelPendingImages() => setState(() => _pendingImages.clear());

  void _removePendingImage(int i) => setState(() => _pendingImages.removeAt(i));

  Future<void> _confirmSendImages() async {
    if (_pendingImages.isEmpty || _activeConversation == null) return;
    final files = List<File>.from(_pendingImages);
    setState(() {
      _pendingImages.clear();
      _sending = true;
    });
    HapticFeedback.lightImpact();

    for (final file in files) {
      final msg =
          await ChatService.sendImageMessage(_activeConversation!.id, file);
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        ChatService.appendMessageToCache(_activeConversation!.id, msg);
        _applyLocalPreview(
          _activeConversation!.id,
          msg.text?.isNotEmpty == true ? msg.text! : '[Image]',
          senderId: msg.senderId,
        );
        _scrollToBottom();
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  /// Group consecutive image-only messages from the same sender.
  List<List<ChatMessage>> get _groupedMessages {
    final groups = <List<ChatMessage>>[];
    int i = 0;
    while (i < _messages.length) {
      final m = _messages[i];
      if (m.messageType == 'image' &&
          m.imageUrl != null &&
          (m.text == null || m.text!.isEmpty)) {
        final batch = <ChatMessage>[m];
        while (i + 1 < _messages.length && batch.length < 5) {
          final next = _messages[i + 1];
          if (next.messageType == 'image' &&
              next.imageUrl != null &&
              (next.text == null || next.text!.isEmpty) &&
              next.senderId == m.senderId) {
            batch.add(next);
            i++;
          } else {
            break;
          }
        }
        groups.add(batch);
      } else {
        groups.add([m]);
      }
      i++;
    }
    return groups;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final maxAvailableHeight = screenHeight - topPadding - 16;
    final targetHeight = bottomInset > 0
        ? (maxAvailableHeight - bottomInset).clamp(240.0, screenHeight * 0.78)
        : (screenHeight * 0.78);

    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: _dismiss,
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),
        // Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: SlideTransition(
            position: _slideAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: targetHeight,
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 30,
                      offset: Offset(0, -5))
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: _quickAnswersMode
                    ? _buildQuickAnswersView()
                    : (_showDetail ? _buildDetailView() : _buildInboxView()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INBOX VIEW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildInboxView() {
    final role = context.watch<AuthProvider>().user?.role;
    final canSearchStores = role == 'customer';
    return Column(
      children: [
        // Header
        _buildDrawerHeader(
          title: 'Messages',
          leading: null,
          trailing: IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.muted, size: 22),
            onPressed: _dismiss,
            splashRadius: 18,
          ),
        ),
        // Store search is customer-only (riders open chats from orders)
        if (canSearchStores) _buildSearchBar(),
        // Search results or conversation list
        Expanded(
          child: _showSearchResults && canSearchStores
              ? _buildSearchResults()
              : _buildConversationList(),
        ),
      ],
    );
  }

  Widget _buildDrawerHeader(
      {required String title, Widget? leading, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (leading != null) leading,
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.charcoal),
        decoration: InputDecoration(
          hintText: 'Search stores to message…',
          hintStyle: GoogleFonts.dmSans(
              fontSize: 13, color: AppColors.muted.withOpacity(0.6)),
          prefixIcon:
              Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
          filled: true,
          fillColor: AppColors.cream,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.borderStrong)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.deepRose)),
          isDense: true,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.muted),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                  splashRadius: 14,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.deepRose, strokeWidth: 2.5));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No stores found',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, thickness: 0.5, indent: 66, color: AppColors.border),
      itemBuilder: (context, i) {
        final store = _searchResults[i];
        final name = store['name'] ?? 'Store';
        final logo = store['logo_url'] as String?;
        final address = store['address'] as String?;
        return InkWell(
          onTap: () {
            _searchController.clear();
            setState(() {
              _showSearchResults = false;
              _searchResults = [];
            });
            _openWithStore(store['id'] as int);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(logo, name, 40, customerDefault: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (store['can_deliver_to_customer'] == true) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 12, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text('Delivers to your address',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                      if (address != null)
                        Text(address,
                            style: GoogleFonts.dmSans(
                                fontSize: 11.5, color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.deepRose,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text('Message',
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliverableStoresRow() {
    if (_deliverableStores.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 15, color: AppColors.deepRose),
                const SizedBox(width: 6),
                Text(
                  'Delivers to your address',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_deliverableStores.length} shops',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _deliverableStores.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final store = _deliverableStores[i];
                final name = store['name']?.toString() ?? 'Store';
                final logo = store['logo_url'] as String?;
                final storeId = store['id'] as int? ?? 0;
                return InkWell(
                  onTap: () {
                    if (storeId > 0) _openWithStore(storeId);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildAvatar(logo, name, 46, customerDefault: false),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUPPORT & QUICK ANSWERS HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAdminAvatar(double size, {bool showOnline = false}) {
    final iconSize = (size * 0.46).clamp(14.0, 24.0);
    final avatar = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7A2F44), Color(0xFFC24E68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );

    if (!showOnline) return avatar;

    final dot = (size * 0.28).clamp(10.0, 14.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: const Color(0xFF31A24C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4031A24C),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar(double size) {
    final iconSize = (size * 0.46).clamp(14.0, 24.0);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6A8F78), Color(0xFF88B094)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Future<void> _openSupportConversation() async {
    if (_openingSupport) return;

    final existing = _conversations.cast<ChatConversation?>().firstWhere(
      (c) => c?.otherUser?.role == 'admin',
      orElse: () => _chatProvider.conversations.cast<ChatConversation?>().firstWhere(
        (c) => c?.otherUser?.role == 'admin',
        orElse: () => ChatService.getSupportConversationSync(),
      ),
    );
    if (existing != null) {
      _openConversation(existing);
      return;
    }

    setState(() => _openingSupport = true);
    try {
      final convo = await ChatService.getOrCreateSupportConversation();
      if (!mounted) return;
      if (convo != null) {
        _openConversation(convo);
      } else {
        showToast(context, 'Could not open support chat.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error opening support: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _openingSupport = false);
      }
    }
  }

  Future<void> _openQuickAnswers() async {
    _stopPoll();
    _stopInboxPresencePoll();
    _chatProvider.setLiveMode(false);
    setState(() {
      _quickAnswersMode = true;
      _showDetail = false;
      _activeConversation = null;
      if (_qaMessages.isEmpty) {
        _qaMessages.add(_QaMessage(
          isUser: false,
          text: 'Hi! Select a question below to get an instant answer.',
        ));
      }
    });

    if (_supportFaqs.isEmpty) {
      setState(() => _loadingFaqs = true);
      try {
        final faqs = await ChatService.getSupportFaqs();
        if (mounted) {
          setState(() {
            _supportFaqs = faqs;
            _loadingFaqs = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _loadingFaqs = false);
        }
      }
    }
  }

  void _selectFaq(SupportFaq faq) {
    setState(() {
      _qaMessages.add(_QaMessage(
        isUser: true,
        text: faq.question,
      ));
      _qaMessages.add(_QaMessage(
        isUser: false,
        text: faq.answer.isNotEmpty ? faq.answer : 'No answer available.',
      ));
    });
    _scrollQaToBottom();
  }

  void _scrollQaToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_qaScrollController.hasClients) {
        _qaScrollController.animateTo(
          _qaScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildQuickAnswersView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            border:
                Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: _backToInbox,
                splashRadius: 18,
              ),
              _buildBotAvatar(34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Answers',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF31a24c),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Auto Help',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 22, color: AppColors.muted),
                onPressed: _dismiss,
                splashRadius: 18,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _loadingFaqs && _supportFaqs.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.deepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : ListView(
                  controller: _qaScrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Bot Welcome Message
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBotAvatar(24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D502846),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Hi! Select a question below to get an instant answer.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                height: 1.4,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // FAQ Questions Chips / Tiles
                    if (_supportFaqs.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 14, color: AppColors.deepRose),
                          const SizedBox(width: 6),
                          Text(
                            'Frequently Asked Questions',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._supportFaqs.map((faq) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectFaq(faq),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x06502846),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.help_outline_rounded,
                                          size: 16, color: AppColors.deepRose),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          faq.question,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.charcoal,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: AppColors.muted.withValues(alpha: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ] else if (!_loadingFaqs) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No FAQs available right now.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // QA Chat History (if user tapped questions)
                    if (_qaMessages.length > 1) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Conversation',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._qaMessages.skip(1).map((msg) {
                        if (msg.isUser) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD2E1),
                                          Color(0xFFF0C8E6)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Text(
                                      msg.text,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBotAvatar(22),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.8)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0D502846),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      msg.text,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }),
                    ],
                    // Still Have Questions Card
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08502846),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildAdminAvatar(36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Still have questions?',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Chat directly with our support team',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _openingSupport
                                ? null
                                : _openSupportConversation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepRose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: _openingSupport
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Contact Support',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildContactSupportTile(ChatConversation? supportConvo) {
    final unread = supportConvo?.unreadCount ?? 0;
    final hasUnread = unread > 0;
    final preview = supportConvo?.lastMessageText ?? 'Chat with admin support';
    final time = supportConvo?.lastMessageAt != null
        ? _timeAgo(supportConvo!.lastMessageAt)
        : '';
    final adminId = supportConvo?.otherUser?.id;
    final isOnline = adminId != null ? _isPartnerOnline(adminId) : false;

    return InkWell(
      onTap: _openSupportConversation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAdminAvatar(44, showOnline: isOnline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Contact Support',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBEBF0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Admin',
                          style: GoogleFonts.dmSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread ? AppColors.charcoal : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.deepRose,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAnswersTile() {
    return InkWell(
      onTap: _openQuickAnswers,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildBotAvatar(44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Quick Answers',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'FAQ Bot',
                          style: GoogleFonts.dmSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to browse common questions',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalConvoTile(ChatConversation convo) {
    final other = convo.otherUser;
    final isSeller = other?.role == 'seller';
    final isRider = other?.role == 'rider' || convo.isRiderThread;
    final storeName = convo.storeName ?? (convo.orderContext?.storeName);
    final displayName = isRider
        ? (storeName != null && storeName.isNotEmpty
            ? '$storeName Rider'
            : (other?.fullName != null && other!.fullName.isNotEmpty
                ? '${other.fullName} (Rider)'
                : 'Rider'))
        : (isSeller
            ? (convo.storeName ?? other?.fullName ?? 'Unknown')
            : (other?.fullName ?? 'Unknown'));
    final displayAvatar =
        isSeller ? (convo.storeLogo ?? other?.avatarUrl) : other?.avatarUrl;
    final unread = convo.unreadCount;
    final hasUnread = unread > 0;

    final isAdmin = other?.role == 'admin';

    return Dismissible(
      key: ValueKey(convo.id),
      direction: isAdmin ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red[400],
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        if (isAdmin) return false;
        final confirmed = await CustomConfirmDialog.show(
          context,
          title: 'Delete Conversation',
          message: 'Delete your conversation with $displayName?',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          isDestructive: true,
          icon: Icons.delete_outline_rounded,
        );
        return confirmed ?? false;
      },
      onDismissed: (_) async {
        if (isAdmin) return;
        final id = convo.id;
        setState(() {
          _conversations.removeWhere((c) => c.id == id);
        });
        await _chatProvider.deleteConversation(id);
      },
      child: InkWell(
        onTap: () => _openConversation(convo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(
                displayAvatar,
                displayName,
                44,
                customerDefault: !isSeller,
                showOnline: _isPartnerOnline(other?.id),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.charcoal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      convo.lastMessageText ?? 'No messages yet',
                      style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color:
                              hasUnread ? AppColors.charcoal : AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_timeAgo(convo.lastMessageAt),
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted)),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                          color: AppColors.deepRose,
                          borderRadius: BorderRadius.circular(9)),
                      child: Center(
                        child: Text(unread > 99 ? '99+' : '$unread',
                            style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_inboxLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.deepRose, strokeWidth: 2.5));
    }
    final role = context.read<AuthProvider>().user?.role;
    final isCustomer = role == 'customer';
    final isAdmin = role == 'admin';

    final supportConvo = _conversations.cast<ChatConversation?>().firstWhere(
      (c) => c?.otherUser?.role == 'admin',
      orElse: () => _chatProvider.conversations.cast<ChatConversation?>().firstWhere(
        (c) => c?.otherUser?.role == 'admin',
        orElse: () => ChatService.getSupportConversationSync(),
      ),
    );
    final normalConvos =
        _conversations.where((c) => c.otherUser?.role != 'admin').toList();

    final showPinnedSupport = !isAdmin;
    final showDeliverableRail = isCustomer && _deliverableStores.isNotEmpty;

    if (normalConvos.isEmpty) {
      final emptyHint = role == 'rider'
          ? 'Open an assigned order to message the customer'
          : 'Tap any store below that delivers to your address or search above to chat';

      return RefreshIndicator(
        onRefresh: _loadInbox,
        color: AppColors.deepRose,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            if (showDeliverableRail) _buildDeliverableStoresRow(),
            if (showPinnedSupport) ...[
              _buildContactSupportTile(supportConvo),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 70,
                  color: AppColors.border),
              _buildQuickAnswersTile(),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 70,
                  color: AppColors.border),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 44, color: AppColors.muted.withValues(alpha: 0.35)),
                  const SizedBox(height: 10),
                  Text('No conversations yet',
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(emptyHint,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.muted.withValues(alpha: 0.8)),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      color: AppColors.deepRose,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (showDeliverableRail) _buildDeliverableStoresRow(),
          if (showPinnedSupport) ...[
            _buildContactSupportTile(supportConvo),
            Divider(
                height: 1,
                thickness: 0.5,
                indent: 70,
                color: AppColors.border),
            _buildQuickAnswersTile(),
            Divider(
                height: 1,
                thickness: 0.5,
                indent: 70,
                color: AppColors.border),
          ],
          ...List.generate(normalConvos.length, (idx) {
            final convo = normalConvos[idx];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNormalConvoTile(convo),
                if (idx < normalConvos.length - 1)
                  Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 70,
                      color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DETAIL VIEW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDetailView() {
    final convo = _activeConversation!;
    final other = convo.otherUser;
    final isAdmin = other?.role == 'admin';
    final isSeller = other?.role == 'seller';
    final isRider = other?.role == 'rider' || convo.isRiderThread;
    final displayName = isAdmin
        ? 'Contact Support'
        : (isRider
            ? (other?.fullName != null && other!.fullName.isNotEmpty
                ? other.fullName
                : (convo.storeName != null && convo.storeName!.isNotEmpty
                    ? '${convo.storeName} Rider'
                    : 'Rider'))
            : (isSeller
                ? (convo.storeName ?? other?.fullName ?? 'Unknown')
                : (other?.fullName ?? 'Unknown')));
    final displayAvatar =
        isSeller ? (convo.storeLogo ?? other?.avatarUrl) : other?.avatarUrl;

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            border:
                Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: _backToInbox,
                  splashRadius: 18),
              InkWell(
                onTap: isSeller && convo.storeId > 0
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StorePage(storeId: convo.storeId),
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: isAdmin
                    ? _buildAdminAvatar(34, showOnline: false)
                    : _buildAvatar(
                        displayAvatar,
                        displayName,
                        34,
                        customerDefault: !isSeller,
                        showOnline: false,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: isSeller && convo.storeId > 0
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StorePage(storeId: convo.storeId),
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(displayName,
                                style: GoogleFonts.dmSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBEBF0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Admin Support',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepRose,
                                ),
                              ),
                            ),
                          ],
                          if (isSeller && convo.storeId > 0) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.muted),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _otherOnline
                                      ? const Color(0xFF31a24c)
                                      : Colors.grey[400])),
                          const SizedBox(width: 4),
                          Text(
                              _otherOnline
                                  ? (isAdmin ? 'Support Online' : 'Online')
                                  : 'Offline',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 22, color: AppColors.muted),
                  onPressed: _dismiss,
                  splashRadius: 18),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _messagesLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.deepRose, strokeWidth: 2.5))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined,
                              size: 40,
                              color: AppColors.muted.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          Text('Start the conversation!',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _groupedMessages.length,
                      itemBuilder: (context, index) {
                        final reversedIndex =
                            _groupedMessages.length - 1 - index;
                        return _buildMessageGroup(
                            _groupedMessages[reversedIndex], reversedIndex);
                      },
                    ),
        ),
        if (_otherIsTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _buildTypingIndicator(),
          ),
        // Image preview bar
        if (_pendingImages.isNotEmpty) _buildImagePreview(),
        if (_showOrderSuggest) _buildOrderSuggestBar(),
        // Input bar
        _buildInputBar(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MESSAGE RENDERING (same as ChatDetailScreen)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildQuotedReply(ChatMessage msg) {
    final isRepliedDeleted = msg.isReplyTargetDeleted;
    final preview = msg.replyPreviewLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.deepRose, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.replyToSenderName != null)
            Text(
              msg.replyToSenderName!,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepRose),
            ),
          const SizedBox(height: 2),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: isRepliedDeleted
                  ? Colors.grey[500]
                  : AppColors.charcoal.withOpacity(0.7),
              fontStyle: isRepliedDeleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageGroup(List<ChatMessage> group, int groupIndex) {
    final msg = group.first;
    final isSent = msg.senderId == _myId;

    bool showDate = groupIndex == 0;
    if (!showDate) {
      final prevGroup = _groupedMessages[groupIndex - 1];
      showDate = _differentDay(prevGroup.first.createdAt, msg.createdAt);
    }

    final lastSentByMe = _messages.lastWhere((m) => m.senderId == _myId,
        orElse: () => _messages.first);
    final isLastSent = isSent && group.contains(lastSentByMe);
    final isImageGrid = group.length > 1 && !msg.isDeleted;
    final isCustomTicket = !msg.isDeleted && msg.customTicket != null;
    final isOrderCard = !msg.isDeleted &&
        (msg.orderCard != null || msg.messageType == 'order_card');

    return Column(
      crossAxisAlignment:
          isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
                child: Text(_formatDate(msg.createdAt),
                    style: GoogleFonts.dmSans(
                        fontSize: 10.5, color: AppColors.muted))),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment:
                isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSent) ...[
                if (msg.senderRole == 'admin')
                  _buildAdminAvatar(22)
                else
                  _buildAvatar(
                    msg.senderAvatar,
                    msg.senderName ?? '',
                    22,
                    customerDefault: msg.senderRole != 'seller',
                  ),
                const SizedBox(width: 5),
              ],
              // Sent: menu sits left of the bubble (toward center), matching web.
              if (isSent && !msg.isDeleted) ...[
                _buildMessageMenu(group.first),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: !msg.isDeleted
                      ? () {
                          HapticFeedback.mediumImpact();
                          _showMessageActionModal(group.first);
                        }
                      : null,
                  child: isOrderCard
                    ? Column(
                        crossAxisAlignment: isSent
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            child: SizedBox(
                              width: 252,
                              child: ChatOrderCardMessage(
                              ctx: _cardContextForMessage(msg),
                              isSent: isSent,
                            ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _formatTime(msg.createdAt),
                              style: GoogleFonts.dmSans(
                                  fontSize: 9.5, color: Colors.grey[500]),
                            ),
                          ),
                        ],
                      )
                    : isCustomTicket
                    ? Column(
                        crossAxisAlignment: isSent
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.82,
                            ),
                            child: SizedBox(
                              width: 270,
                              child: ChatCustomTicketCard(
                                ticket: msg.customTicket!,
                                isSent: isSent,
                                onViewOrderPressed: () {
                                  widget.onClose();
                                  final orderId = msg.customTicket?.orderId;
                                  MainShell.switchTab(context, 3, targetOrderStatus: 'pending', targetOrderId: orderId);
                                },
                                onReviewPressed: () {
                                  CustomTicketCheckoutSheet.show(
                                    context,
                                    ticket: msg.customTicket!,
                                    onOrderPlaced: () {
                                      setState(() => msg.customTicket!.status = 'accepted');
                                      _loadMessages();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _formatTime(msg.createdAt),
                              style: GoogleFonts.dmSans(
                                  fontSize: 9.5, color: Colors.grey[500]),
                            ),
                          ),
                        ],
                      )
                    : Container(
                  constraints: BoxConstraints(
                      maxWidth: isImageGrid
                          ? 160.0
                          : MediaQuery.of(context).size.width * 0.68),
                  padding: EdgeInsets.symmetric(
                      horizontal: isImageGrid ? 5 : 12,
                      vertical: isImageGrid ? 5 : 8),
                  decoration: BoxDecoration(
                    color: msg.isDeleted
                        ? (isSent
                            ? const Color(0xFFE8E8E8)
                            : const Color(0xFFF1F3F5))
                        : (isSent
                            ? null
                            : const Color(0xF5FFFFFF)),
                    gradient: (!msg.isDeleted && isSent)
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF2D2E1), // match web chat sent bubble
                              Color(0xFFE8C4DC),
                            ],
                          )
                        : null,
                    border: Border.all(
                      color: msg.isDeleted
                          ? const Color(0x00000000)
                          : (isSent
                              ? const Color(0x8CFFFFFF)
                              : const Color(0xB3FFFFFF)),
                      width: 1,
                    ),
                    boxShadow: (!msg.isDeleted && !isSent)
                        ? const [
                            BoxShadow(
                              color: Color(0x0D502846),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSent ? 16 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isSent
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // ── Quoted reply ──
                      if (msg.replyToId != null) _buildQuotedReply(msg),
                      // ── Deleted message ──
                      if (msg.isDeleted) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Message has been deleted',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_formatTime(msg.createdAt),
                            style: GoogleFonts.dmSans(
                                fontSize: 9.5, color: Colors.grey[500])),
                      ] else ...[
                        if (isImageGrid)
                          _buildImageGrid(group)
                        else if (msg.messageType == 'image' &&
                            msg.imageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () => _viewImage(msg.imageUrl!),
                              child: CachedNetworkImage(
                                imageUrl: msg.imageUrl!,
                                width: 130,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                    width: 130,
                                    height: 90,
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                                errorWidget: (_, __, ___) => Container(
                                    width: 130,
                                    height: 50,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey)),
                              ),
                            ),
                          ),
                          if (msg.text != null && msg.text!.isNotEmpty)
                            const SizedBox(height: 3),
                        ],
                        if (!isImageGrid &&
                            msg.messageType != 'order_card' &&
                            msg.text != null &&
                            msg.text!.isNotEmpty)
                          Text(msg.text!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  color: AppColors.charcoal,
                                  height: 1.4)),
                        const SizedBox(height: 2),
                        Text(_formatTime(msg.createdAt),
                            style: GoogleFonts.dmSans(
                                fontSize: 9.5, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ),
              ),
            ),
              // Received: menu sits right of the bubble (toward center).
              if (!isSent && !msg.isDeleted) ...[
                const SizedBox(width: 4),
                _buildMessageMenu(group.first),
              ],
            ],
          ),
        ),
        if (isLastSent && group.last.isRead)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text('Seen',
                style:
                    GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted)),
          ),
      ],
    );
  }

  Widget _buildMessageMenu(ChatMessage msg) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showMessageActionModal(msg);
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.roseCta.withOpacity(0.12),
        highlightColor: AppColors.roseCta.withOpacity(0.06),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.035),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
              width: 0.8,
            ),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            size: 17,
            color: AppColors.muted.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  void _showMessageActionModal(ChatMessage msg) {
    final isSent = msg.senderId == _myId;
    final hasText = msg.text != null && msg.text!.trim().isNotEmpty;
    final isImage = msg.messageType == 'image' && msg.imageUrl != null;
    final senderName = isSent
        ? 'You'
        : (msg.senderName != null && msg.senderName!.isNotEmpty
            ? msg.senderName!
            : (_activeConversation?.storeName ??
                _activeConversation?.otherUser?.fullName ??
                'Message'));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.38),
      builder: (sheetCtx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Message Preview Card ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0x1F6B4C3B),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3.5,
                        height: 36,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(
                          color: isSent ? AppColors.roseCta : AppColors.sage,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  senderName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSent
                                        ? AppColors.roseCta
                                        : AppColors.charcoal,
                                  ),
                                ),
                                Text(
                                  _formatTime(msg.createdAt),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            if (isImage)
                              Row(
                                children: [
                                  Icon(Icons.image_outlined,
                                      size: 13, color: AppColors.muted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      hasText ? msg.text! : 'Photo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: AppColors.charcoal
                                            .withOpacity(0.75),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (msg.messageType == 'order_card')
                              Row(
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 13, color: AppColors.muted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Order summary card',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppColors.charcoal
                                          .withOpacity(0.75),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                msg.text ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  color: AppColors.charcoal.withOpacity(0.85),
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isImage) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: msg.imageUrl!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 38,
                              height: 38,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image_rounded,
                                  size: 16, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Action Options ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      // Reply
                      _buildModalActionTile(
                        icon: Icons.reply_rounded,
                        iconColor: AppColors.roseCta,
                        badgeColor: const Color(0xFFFDEEF2),
                        title: 'Reply',
                        subtitle: 'Quote this message in your response',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _setReplyTo(msg);
                        },
                      ),

                      // Copy text (if text exists)
                      if (hasText) ...[
                        const SizedBox(height: 4),
                        _buildModalActionTile(
                          icon: Icons.copy_rounded,
                          iconColor: const Color(0xFF4A4458),
                          badgeColor: const Color(0xFFF0EFF4),
                          title: 'Copy Text',
                          subtitle: 'Copy content to clipboard',
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _copyMessage(msg);
                          },
                        ),
                      ],

                      // View Photo (if image exists)
                      if (isImage) ...[
                        const SizedBox(height: 4),
                        _buildModalActionTile(
                          icon: Icons.fullscreen_rounded,
                          iconColor: const Color(0xFF1976D2),
                          badgeColor: const Color(0xFFE3F2FD),
                          title: 'View Photo',
                          subtitle: 'Open photo in full size',
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _viewImage(msg.imageUrl!);
                          },
                        ),
                      ],

                      // Delete (only if sent by current user)
                      if (isSent) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          child: Divider(
                              height: 1, color: Colors.black.withOpacity(0.06)),
                        ),
                        _buildModalActionTile(
                          icon: Icons.delete_outline_rounded,
                          iconColor: const Color(0xFFE53935),
                          badgeColor: const Color(0xFFFFEBEE),
                          title: 'Delete Message',
                          titleColor: const Color(0xFFE53935),
                          subtitle: 'Remove message for everyone',
                          subtitleColor: const Color(0xFFEF9A9A),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _deleteMessage(msg);
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalActionTile({
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: iconColor.withOpacity(0.08),
        highlightColor: iconColor.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? AppColors.charcoal,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          color: subtitleColor ?? AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyMessage(ChatMessage msg) {
    if (msg.text != null && msg.text!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: msg.text!));
      showToast(context, 'Copied to clipboard');
    }
  }

  void _setReplyTo(ChatMessage msg) {
    setState(() => _replyingTo = msg);
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: 'Delete message?',
      message: 'This message will be removed for everyone. This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true || _activeConversation == null) return;

    try {
      final updated =
          await ChatService.deleteMessage(_activeConversation!.id, msg.id);
      if (updated != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) _messages[idx] = updated;
        });
      } else if (mounted) {
        showToast(context, 'Failed to delete message', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to delete message: $e', isError: true);
      }
    }
  }

  Widget _buildImageGrid(List<ChatMessage> imgs) {
    final size = imgs.length <= 2 ? 68.0 : 46.0;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: imgs
          .map((m) => GestureDetector(
                onTap: () => _viewImage(m.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: CachedNetworkImage(
                    imageUrl: m.imageUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: size,
                        height: size,
                        color: Colors.grey[200],
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(
                        width: size,
                        height: size,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.grey, size: 14)),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Text(
          '${_typingName ?? 'Someone'} is typing',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(width: 6),
        const _DotsIndicator(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.warmWhite,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (context, i) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(_pendingImages[i],
                              width: 50, height: 50, fit: BoxFit.cover)),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: GestureDetector(
                          onTap: () => _removePendingImage(i),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('${_pendingImages.length}/5',
              style:
                  GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted)),
          IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.muted, size: 18),
              onPressed: _cancelPendingImages,
              splashRadius: 16),
        ],
      ),
    );
  }

  Widget _buildOrderSuggestBar() {
    final isRider = context.read<AuthProvider>().user?.role == 'rider';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.blush.withOpacity(0.28),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isRider
                  ? 'Share this order so the customer knows which delivery you mean.'
                  : 'Share this order so your rider knows what you’re asking about.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.charcoal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _shareOrderCard,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.deepRose,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Share order',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: () => setState(() {
              _orderSuggestDismissed = true;
              _suggestOrderId = null;
            }),
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply indicator
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border(
                  top: BorderSide(color: AppColors.borderStrong, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.deepRose,
                        borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying to ${_replyingTo!.senderName ?? "user"}',
                          style: GoogleFonts.dmSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepRose)),
                      Text(
                        _replyingTo!.messageType == 'order_card'
                            ? _replyingTo!.orderCardPreview
                            : (_replyingTo!.text ?? '(Image)'),
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppColors.charcoal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.muted),
                ),
              ],
            ),
          ),
        // Input bar
        Builder(builder: (context) {
          final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          return Container(
            padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 7,
                bottom: isKeyboardOpen
                    ? 7
                    : (MediaQuery.of(context).padding.bottom + 7)),
            decoration: BoxDecoration(
                color: AppColors.warmWhite,
                border:
                    Border(top: BorderSide(color: AppColors.border, width: 0.5))),
          child: Row(
            children: [
              IconButton(
                  icon: Icon(Icons.camera_alt_outlined,
                      color: AppColors.muted, size: 20),
                  onPressed: _sending ? null : _takePhoto,
                  splashRadius: 18),
              IconButton(
                  icon: Icon(Icons.image_outlined,
                      color: AppColors.muted, size: 20),
                  onPressed: _sending ? null : _pickImage,
                  splashRadius: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: AppColors.borderStrong, width: 1)),
                  child: TextField(
                    controller: _msgController,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendText(),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.dmSans(
                        fontSize: 13.5, color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          color: AppColors.muted.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      isDense: true,
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    gradient: AppColors.roseGradient, shape: BoxShape.circle),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 16),
                  onPressed: _sending ? null : _sendText,
                  splashRadius: 18,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAvatar(
    String? url,
    String name,
    double size, {
    bool customerDefault = true,
    bool showOnline = false,
  }) {
    final Widget avatar;
    if (url != null && url.isNotEmpty) {
      avatar = ClipOval(
        child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                _placeholderAvatar(name, size, customerDefault: customerDefault)),
      );
    } else {
      avatar = _placeholderAvatar(name, size, customerDefault: customerDefault);
    }

    if (!showOnline) return avatar;

    final dot = (size * 0.28).clamp(10.0, 14.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: const Color(0xFF31A24C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4031A24C),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar(String name, double size, {bool customerDefault = true}) {
    if (customerDefault) {
      return CustomerDefaultAvatar(size: size);
    }
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty
            ? parts[0][0].toUpperCase()
            : '?');
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          gradient: AppColors.roseGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: GoogleFonts.dmSans(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
                alignment: Alignment.topRight,
                child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(ctx))),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                      height: 200,
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)))),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? iso) => formatRelativeFromIso(iso);

  bool _differentDay(String a, String b) => isDifferentPhilippineDay(a, b);

  String _formatDate(String iso) => formatPhilippineChatDayLabel(iso);

  String _formatTime(String iso) => formatPhilippineTime12hFromIso(iso);
}

/// Animated three-dots typing indicator.
class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -4)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, child) => Transform.translate(
              offset: Offset(0, _animations[i].value), child: child),
          child: Container(
              width: 4.5,
              height: 4.5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.grey[500])),
        );
      }),
    );
  }
}

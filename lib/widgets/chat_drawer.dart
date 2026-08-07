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
import 'chat_order_context_banner.dart';

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
  static const double _expandedRight = 20;
  static const double _dockedRight = 0;

  late final AnimationController _anim;
  /// 0 = fully expanded circle, 1 = docked edge tab.
  double _progress = 0;
  double _dragStartProgress = 0;
  bool _dragging = false;

  bool get _docked => _progress > 0.85;

  double get _right =>
      _expandedRight + (_dockedRight - _expandedRight) * _progress;

  double get _width =>
      _expandedSize + (_tabWidth - _expandedSize) * _progress;

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
        _progress =
            start + (target - start) * Curves.easeOutCubic.transform(_anim.value);
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottom = widget.bottomNavClearance + safeBottom;
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

class ChatDrawerState extends State<ChatDrawer> with TickerProviderStateMixin {
  // ═══ VIEW STATE ═══
  bool _showDetail = false;
  ChatConversation? _activeConversation;
  /// Kept separate from inbox rows so message/preview polls don't wipe it.
  ChatOrderContext? _orderContext;

  // ═══ INBOX ═══
  List<ChatConversation> _conversations = [];
  bool _inboxLoading = true;

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
  List<File> _pendingImages = [];
  ChatMessage? _replyingTo; // Track which message is being replied to
  late final ChatProvider _chatProvider;
  Timer? _pollTimer;
  Timer? _typingDebounce;
  Timer? _inboxSyncTimer;

  int get _myId => context.read<AuthProvider>().user?.id ?? 0;

  // ═══ ANIMATION ═══
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
    _chatProvider.setLiveMode(true);
    _loadInbox();
    _startInboxSync();

    if (widget.openCustomerId != null || widget.openStoreId != null || widget.openOrderId != null) {
      _openWithContext();
    }
  }

  @override
  void dispose() {
    _chatProvider.setLiveMode(false);
    _slideController.dispose();
    _searchController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    _typingDebounce?.cancel();
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
    final convos = await ChatService.getConversations();
    if (!mounted) return;
    // Keep optimistic unread clears while server catches up
    final merged = convos.map((c) {
      final localIdx = _conversations.indexWhere((x) => x.id == c.id);
      if (localIdx != -1 && _conversations[localIdx].unreadCount == 0 && c.unreadCount > 0) {
        return c.copyWith(unreadCount: 0);
      }
      // Prefer newer local preview if timestamps look equal/older (just sent)
      if (localIdx != -1) {
        final local = _conversations[localIdx];
        final localAt = local.lastMessageAt;
        final serverAt = c.lastMessageAt;
        if (localAt != null &&
            localAt.isNotEmpty &&
            (serverAt == null || serverAt.isEmpty || localAt.compareTo(serverAt) >= 0) &&
            local.lastMessageText != null &&
            local.lastMessageText != c.lastMessageText) {
          return c.copyWith(
            lastMessageText: local.lastMessageText,
            lastMessageAt: localAt,
            lastSenderId: local.lastSenderId,
            unreadCount: 0,
          );
        }
      }
      return c;
    }).toList();
    setState(() {
      _conversations = merged;
      _inboxLoading = false;
    });
    final total = merged.fold<int>(0, (sum, c) => sum + c.unreadCount);
    _chatProvider.syncUnreadTotal(total);
    _chatProvider.refreshUnread();
  }

  void _startInboxSync() {
    _inboxSyncTimer?.cancel();
    _inboxSyncTimer = Timer.periodic(AppQuality.instance.chatInboxSyncInterval, (_) async {
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
    _chatProvider.markConversationReadLocal(conversationId, knownUnread: cleared > 0 ? cleared : null);
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
            orderContext: _orderContext ?? _activeConversation!.orderContext ?? updated.orderContext,
            isRiderThread: _activeConversation!.isRiderThread || updated.isRiderThread || _orderContext != null,
          );
        }
      });
    }
    _chatProvider.touchConversationPreview(
      conversationId: conversationId,
      previewText: preview,
      senderId: senderId,
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
    setState(() {
      _showDetail = true;
      _activeConversation = convo;
      _orderContext = convo.orderContext;
      _messages = [];
      _messagesLoading = true;
      _pendingImages.clear();
      _otherIsTyping = false;
      _otherOnline = false;
    });
    _loadMessages(forceScroll: true);
    _applyLocalRead(convo.id);
    _markRead();
    _checkOnline();
    _startPoll();
    _ensureOrderContext(convo);
  }

  Future<void> _ensureOrderContext(ChatConversation convo) async {
    final role = context.read<AuthProvider>().user?.role;
    final looksLikeRiderThread = convo.isRiderThread
        || convo.orderContext != null
        || _orderContext != null
        || convo.otherUser?.role == 'rider'
        || role == 'rider';
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
      final convo = await ChatService.getOrCreateRiderConversation(widget.openOrderId!);
      if (!mounted) return;
      if (convo != null) {
        _openConversation(convo);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open rider chat for this order.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No existing conversation with this customer yet.')),
      );
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
      _activeConversation = null;
      _orderContext = null;
      _messages = [];
      _pendingImages.clear();
    });
    // Local preview/unread already updated — paint immediately, reconcile in background
    _chatProvider.refreshUnread();
    _loadInbox();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MESSAGE LOGIC (same as ChatDetailScreen)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadMessages({bool forceScroll = false}) async {
    if (_activeConversation == null) return;
    final previousIds = _messages.map((m) => m.id).toSet();
    final nearBottom = !_scrollController.hasClients ||
        (_scrollController.position.maxScrollExtent - _scrollController.offset) < 140;
    final msgs = await ChatService.getMessages(_activeConversation!.id, perPage: 50);
    if (!mounted) return;
    final hasNew = msgs.any((m) => !previousIds.contains(m.id));
    setState(() {
      _messages = msgs;
      _messagesLoading = false;
    });
    if (forceScroll || previousIds.isEmpty || (hasNew && nearBottom)) {
      _scrollToBottom();
    }
    if (hasNew && msgs.isNotEmpty) {
      final last = msgs.last;
      final preview = last.messageType == 'image'
          ? (last.text?.isNotEmpty == true ? last.text! : '[Image]')
          : (last.text ?? '');
      _applyLocalPreview(_activeConversation!.id, preview, senderId: last.senderId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markRead() async {
    if (_activeConversation == null) return;
    final id = _activeConversation!.id;
    _applyLocalRead(id);
    final ok = await ChatService.markAsRead(id);
    if (!mounted) return;
    await _chatProvider.refreshUnread();
    if (ok) _chatProvider.confirmConversationRead(id);
  }

  Future<void> _checkOnline() async {
    if (_activeConversation == null) return;
    final otherId = _activeConversation!.otherUser?.id ?? _activeConversation!.sellerId;
    final online = await ChatService.isUserOnline(otherId);
    if (mounted) setState(() => _otherOnline = online);
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppQuality.instance.chatMessagePollInterval, (_) async {
      await _loadMessages();
      await _pollTyping();
      _markRead();
    });
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTyping() async {
    if (_activeConversation == null) return;
    final typing = await ChatService.getTyping(_activeConversation!.id);
    if (mounted) {
      setState(() {
        _otherIsTyping = typing.isNotEmpty;
        _typingName = typing.isNotEmpty ? typing.first['full_name'] : null;
      });
    }
  }

  void _onTextChanged(String _) {
    if (_activeConversation == null) return;
    _typingDebounce?.cancel();
    ChatService.sendTyping(_activeConversation!.id);
    _typingDebounce = Timer(const Duration(seconds: 3), () {});
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

    final msg = await ChatService.sendMessage(_activeConversation!.id, text, replyToId: replyId);
    if (msg != null && mounted) {
      setState(() {
        _messages.add(msg);
        _sending = false;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  Future<void> _pickImage() async {
    if (_pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 5 images at a time.')),
      );
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pendingImages.add(File(picked.path)));
  }

  Future<void> _takePhoto() async {
    if (_pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 5 images at a time.')),
      );
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
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
      final msg = await ChatService.sendImageMessage(_activeConversation!.id, file);
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
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
      if (m.messageType == 'image' && m.imageUrl != null && (m.text == null || m.text!.isEmpty)) {
        final batch = <ChatMessage>[m];
        while (i + 1 < _messages.length && batch.length < 5) {
          final next = _messages[i + 1];
          if (next.messageType == 'image' && next.imageUrl != null && (next.text == null || next.text!.isEmpty) && next.senderId == m.senderId) {
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
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: _dismiss,
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),
        // Drawer
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -5))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: _showDetail ? _buildDetailView() : _buildInboxView(),
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

  Widget _buildDrawerHeader({required String title, Widget? leading, Widget? trailing}) {
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
              style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.charcoal),
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
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
          filled: true,
          fillColor: AppColors.cream,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.borderStrong)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.deepRose)),
          isDense: true,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
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
      return const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2.5));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No stores found', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, indent: 66, color: AppColors.border),
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
                _buildAvatar(logo, name, 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.charcoal), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (address != null)
                        Text(address, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.deepRose, borderRadius: BorderRadius.circular(16)),
                  child: Text('Message', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationList() {
    if (_inboxLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2.5));
    }
    if (_conversations.isEmpty) {
      final role = context.read<AuthProvider>().user?.role;
      final emptyHint = role == 'rider'
          ? 'Open an assigned order to message the customer'
          : 'Search a store above to start chatting';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.muted.withOpacity(0.3)),
            const SizedBox(height: 14),
            Text('No conversations yet', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(emptyHint, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted.withOpacity(0.7)), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInbox,
      color: AppColors.deepRose,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, indent: 70, color: AppColors.border),
        itemBuilder: (context, i) {
          final convo = _conversations[i];
          final other = convo.otherUser;
          final isSeller = other?.role == 'seller';
          final displayName = isSeller ? (convo.storeName ?? other?.fullName ?? 'Unknown') : (other?.fullName ?? 'Unknown');
          final displayAvatar = isSeller ? (convo.storeLogo ?? other?.avatarUrl) : other?.avatarUrl;
          final unread = convo.unreadCount;
          final hasUnread = unread > 0;

          return Dismissible(
            key: ValueKey(convo.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Colors.red[400],
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
            ),
            confirmDismiss: (_) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete Conversation', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  content: Text('Delete your conversation with $displayName?', style: GoogleFonts.dmSans()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red[600]))),
                  ],
                ),
              );
              if (confirmed == true) {
                await context.read<ChatProvider>().deleteConversation(convo.id);
                _loadInbox();
              }
              return false;
            },
            child: InkWell(
              onTap: () => _openConversation(convo),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildAvatar(displayAvatar, displayName, 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600, color: AppColors.charcoal),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            convo.lastMessageText ?? 'No messages yet',
                            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400, color: hasUnread ? AppColors.charcoal : AppColors.muted),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_timeAgo(convo.lastMessageAt), style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                        if (hasUnread) ...[
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(color: AppColors.deepRose, borderRadius: BorderRadius.circular(9)),
                            child: Center(
                              child: Text(unread > 99 ? '99+' : '$unread', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
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
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DETAIL VIEW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDetailView() {
    final convo = _activeConversation!;
    final other = convo.otherUser;
    final isSeller = other?.role == 'seller';
    final displayName = isSeller ? (convo.storeName ?? other?.fullName ?? 'Unknown') : (other?.fullName ?? 'Unknown');
    final displayAvatar = isSeller ? (convo.storeLogo ?? other?.avatarUrl) : other?.avatarUrl;

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: _backToInbox, splashRadius: 18),
              _buildAvatar(displayAvatar, displayName, 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: GoogleFonts.dmSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.charcoal), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: _otherOnline ? const Color(0xFF31a24c) : Colors.grey[400])),
                        const SizedBox(width: 4),
                        Text(_otherOnline ? 'Online' : 'Offline', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(icon: Icon(Icons.close_rounded, size: 22, color: AppColors.muted), onPressed: _dismiss, splashRadius: 18),
            ],
          ),
        ),
        if (_orderContext != null) ChatOrderContextBanner(orderContext: _orderContext!),
        // Messages
        Expanded(
          child: _messagesLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2.5))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined, size: 40, color: AppColors.muted.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          Text('Start the conversation!', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _groupedMessages.length + (_otherIsTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _groupedMessages.length) return _buildTypingIndicator();
                        return _buildMessageGroup(_groupedMessages[index], index);
                      },
                    ),
        ),
        // Typing indicator inline
        if (_otherIsTyping && _messages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: _buildTypingIndicator(),
          ),
        // Image preview bar
        if (_pendingImages.isNotEmpty) _buildImagePreview(),
        // Input bar
        _buildInputBar(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MESSAGE RENDERING (same as ChatDetailScreen)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildQuotedReply(ChatMessage msg) {
    final isRepliedDeleted = msg.replyToText == null;
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
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.deepRose),
            ),
          const SizedBox(height: 2),
          Text(
            isRepliedDeleted ? 'Message has been deleted' : msg.replyToText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: isRepliedDeleted ? Colors.grey[500] : AppColors.charcoal.withOpacity(0.7),
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

    final lastSentByMe = _messages.lastWhere((m) => m.senderId == _myId, orElse: () => _messages.first);
    final isLastSent = isSent && group.contains(lastSentByMe);
    final isImageGrid = group.length > 1 && !msg.isDeleted;

    return Column(
      crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(child: Text(_formatDate(msg.createdAt), style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted))),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSent) ...[
                _buildAvatar(msg.senderAvatar, msg.senderName ?? '', 22),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isImageGrid ? 160.0 : MediaQuery.of(context).size.width * 0.68),
                  padding: EdgeInsets.symmetric(horizontal: isImageGrid ? 5 : 12, vertical: isImageGrid ? 5 : 8),
                  decoration: BoxDecoration(
                    color: msg.isDeleted
                        ? (isSent ? const Color(0xFFE8E8E8) : const Color(0xFFF1F3F5))
                        : (isSent ? const Color(0xFFDCF8C5) : const Color(0xFFF1F3F5)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSent ? 16 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // ── Quoted reply ──
                      if (msg.replyToId != null) _buildQuotedReply(msg),
                      // ── Deleted message ──
                      if (msg.isDeleted) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Message has been deleted',
                              style: GoogleFonts.dmSans(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_formatTime(msg.createdAt), style: GoogleFonts.dmSans(fontSize: 9.5, color: Colors.grey[500])),
                      ] else ...[
                        if (isImageGrid)
                          _buildImageGrid(group)
                        else if (msg.messageType == 'image' && msg.imageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () => _viewImage(msg.imageUrl!),
                              child: CachedNetworkImage(
                                imageUrl: msg.imageUrl!,
                                width: 130,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(width: 130, height: 90, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                errorWidget: (_, __, ___) => Container(width: 130, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                              ),
                            ),
                          ),
                          if (msg.text != null && msg.text!.isNotEmpty) const SizedBox(height: 3),
                        ],
                        if (!isImageGrid && msg.text != null && msg.text!.isNotEmpty)
                          Text(msg.text!, style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(_formatTime(msg.createdAt), style: GoogleFonts.dmSans(fontSize: 9.5, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (!msg.isDeleted) _buildMessageMenu(group.first),
            ],
          ),
        ),
        if (isLastSent && group.last.isRead)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text('Seen', style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted)),
          ),
      ],
    );
  }

  Widget _buildMessageMenu(ChatMessage msg) {
    final isSent = msg.senderId == _myId;
    return PopupMenuButton<String>(
      onSelected: (action) {
        if (action == 'copy') _copyMessage(msg);
        else if (action == 'reply') _setReplyTo(msg);
        else if (action == 'delete') _deleteMessage(msg);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'copy', child: Row(children: [const Icon(Icons.copy_rounded, size: 18), const SizedBox(width: 8), const Text('Copy')])),
        PopupMenuItem(value: 'reply', child: Row(children: [const Icon(Icons.reply_rounded, size: 18), const SizedBox(width: 8), const Text('Reply')])),
        if (isSent) PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_rounded, size: 18, color: Colors.red), const SizedBox(width: 8), const Text('Delete', style: TextStyle(color: Colors.red))])),
      ],
      offset: const Offset(0, -100),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted.withOpacity(0.6)),
      ),
    );
  }

  void _copyMessage(ChatMessage msg) {
    if (msg.text != null && msg.text!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: msg.text!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(milliseconds: 1500)));
    }
  }

  void _setReplyTo(ChatMessage msg) {
    setState(() => _replyingTo = msg);
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete message?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        content: Text('This action cannot be undone.', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red[600]))),
        ],
      ),
    );
    if (confirmed != true || _activeConversation == null) return;
    
    try {
      final updated = await ChatService.deleteMessage(_activeConversation!.id, msg.id);
      if (updated != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) _messages[idx] = updated;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  Widget _buildImageGrid(List<ChatMessage> imgs) {
    final size = imgs.length <= 2 ? 68.0 : 46.0;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: imgs.map((m) => GestureDetector(
        onTap: () => _viewImage(m.imageUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CachedNetworkImage(
            imageUrl: m.imageUrl!,
            width: size, height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: size, height: size, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(width: size, height: size, color: Colors.grey[200], child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 14)),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_typingName ?? 'Someone'} is typing', style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(width: 4),
                const _DotsIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.warmWhite, border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
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
                      ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.file(_pendingImages[i], width: 50, height: 50, fit: BoxFit.cover)),
                      Positioned(
                        top: -3, right: -3,
                        child: GestureDetector(
                          onTap: () => _removePendingImage(i),
                          child: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 10),
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
          Text('${_pendingImages.length}/5', style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted)),
          IconButton(icon: Icon(Icons.close_rounded, color: AppColors.muted, size: 18), onPressed: _cancelPendingImages, splashRadius: 16),
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
              border: Border(top: BorderSide(color: AppColors.borderStrong, width: 1)),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 40, decoration: BoxDecoration(color: AppColors.deepRose, borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying to ${_replyingTo!.senderName ?? "user"}', style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.deepRose)),
                      Text(
                        _replyingTo!.text ?? '(Image)',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.charcoal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                ),
              ],
            ),
          ),
        // Input bar
        Container(
          padding: EdgeInsets.only(left: 8, right: 8, top: 7, bottom: MediaQuery.of(context).padding.bottom + 7),
          decoration: BoxDecoration(color: AppColors.warmWhite, border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.camera_alt_outlined, color: AppColors.muted, size: 20), onPressed: _sending ? null : _takePhoto, splashRadius: 18),
              IconButton(icon: Icon(Icons.image_outlined, color: AppColors.muted, size: 20), onPressed: _sending ? null : _pickImage, splashRadius: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderStrong, width: 1)),
                  child: TextField(
                    controller: _msgController,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendText(),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.muted.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      isDense: true,
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(gradient: AppColors.roseGradient, shape: BoxShape.circle),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  onPressed: _sending ? null : _sendText,
                  splashRadius: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAvatar(String? url, String name, double size) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholderAvatar(name, size)),
      );
    }
    return _placeholderAvatar(name, size);
  }

  Widget _placeholderAvatar(String name, double size) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?');
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(gradient: AppColors.roseGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: GoogleFonts.dmSans(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: Colors.white)),
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
            Align(alignment: Alignment.topRight, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, placeholder: (_, __) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white)))),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d).inSeconds;
      if (diff < 60) return 'now';
      if (diff < 3600) return '${diff ~/ 60}m';
      if (diff < 86400) return '${diff ~/ 3600}h';
      return '${diff ~/ 86400}d';
    } catch (_) {
      return '';
    }
  }

  bool _differentDay(String a, String b) {
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.year != db.year || da.month != db.month || da.day != db.day;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
      final y = now.subtract(const Duration(days: 1));
      if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Yesterday';
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
    } catch (_) {
      return '';
    }
  }
}

/// Animated three-dots typing indicator.
class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _animations = _controllers.map((c) => Tween<double>(begin: 0, end: -4).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
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
          builder: (_, child) => Transform.translate(offset: Offset(0, _animations[i].value), child: child),
          child: Container(width: 4.5, height: 4.5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[500])),
        );
      }),
    );
  }
}

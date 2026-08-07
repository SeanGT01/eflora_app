import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/app_quality.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_order_context_banner.dart';

/// Instagram-style chat detail screen.
class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _otherIsTyping = false;
  String? _typingName;
  bool _otherOnline = false;
  List<File> _pendingImages = [];
  ChatOrderContext? _orderContext;

  Timer? _pollTimer;
  Timer? _typingDebounce;
  Timer? _typingKeepAlive;
  Timer? _typingPollTimer;
  DateTime? _lastTypingPing;

  int get _myId => context.read<AuthProvider>().user?.id ?? 0;

  /// Group consecutive image-only messages from the same sender into a single entry.
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

  @override
  void initState() {
    super.initState();
    _orderContext = widget.conversation.orderContext;
    _loadMessages(forceScroll: true);
    _markRead();
    _checkOnline();
    _ensureOrderContext();
    _startPoll();
  }

  Future<void> _ensureOrderContext() async {
    if (_orderContext != null) return;
    final role = context.read<AuthProvider>().user?.role;
    final looksLikeRiderThread = widget.conversation.isRiderThread
        || widget.conversation.otherUser?.role == 'rider'
        || role == 'rider';
    if (!looksLikeRiderThread) return;

    final enriched = await ChatService.getConversation(widget.conversation.id);
    if (!mounted || enriched?.orderContext == null) return;
    setState(() => _orderContext = enriched!.orderContext);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingDebounce?.cancel();
    _typingKeepAlive?.cancel();
    _typingPollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool forceScroll = false}) async {
    final previousIds = _messages.map((m) => m.id).toSet();
    final nearBottom = !_scrollController.hasClients ||
        (_scrollController.position.maxScrollExtent - _scrollController.offset) < 140;
    final msgs = await ChatService.getMessages(widget.conversation.id, perPage: 50);
    if (!mounted) return;
    final hasNew = msgs.any((m) => !previousIds.contains(m.id));
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    if (forceScroll || previousIds.isEmpty || (hasNew && nearBottom)) {
      _scrollToBottom();
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
    final id = widget.conversation.id;
    context.read<ChatProvider>().markConversationReadLocal(
      id,
      knownUnread: widget.conversation.unreadCount,
    );
    final ok = await ChatService.markAsRead(id);
    if (!mounted) return;
    await context.read<ChatProvider>().refreshUnread();
    if (ok) context.read<ChatProvider>().confirmConversationRead(id);
  }

  Future<void> _checkOnline() async {
    final otherId = widget.conversation.otherUser?.id ?? widget.conversation.sellerId;
    final online = await ChatService.isUserOnline(otherId);
    if (mounted) setState(() => _otherOnline = online);
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _pollTimer = Timer.periodic(AppQuality.instance.chatMessagePollInterval, (_) async {
      await _loadMessages();
      _markRead();
    });
    // Faster typing poll so the indicator feels live.
    _typingPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _pollTyping();
    });
    _pollTyping();
  }

  Future<void> _pollTyping() async {
    final typing = await ChatService.getTyping(widget.conversation.id);
    if (!mounted) return;
    final nextTyping = typing.isNotEmpty;
    final nextName = nextTyping ? typing.first['full_name'] as String? : null;
    if (nextTyping == _otherIsTyping && nextName == _typingName) return;
    setState(() {
      _otherIsTyping = nextTyping;
      _typingName = nextName;
    });
  }

  void _pingTyping() {
    final now = DateTime.now();
    if (_lastTypingPing != null &&
        now.difference(_lastTypingPing!) < const Duration(milliseconds: 1800)) {
      return;
    }
    _lastTypingPing = now;
    ChatService.sendTyping(widget.conversation.id);
  }

  void _onTextChanged(String text) {
    if (text.trim().isEmpty) {
      _typingKeepAlive?.cancel();
      _typingKeepAlive = null;
      return;
    }
    _pingTyping();
    _typingDebounce?.cancel();
    _typingKeepAlive?.cancel();
    _typingKeepAlive = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_controller.text.trim().isEmpty) {
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
    // If there are pending images, send those instead
    if (_pendingImages.isNotEmpty) {
      await _confirmSendImages();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);
    HapticFeedback.lightImpact();

    final msg = await ChatService.sendMessage(widget.conversation.id, text);
    if (msg != null && mounted) {
      setState(() {
        _messages.add(msg);
        _sending = false;
      });
      context.read<ChatProvider>().touchConversationPreview(
        conversationId: widget.conversation.id,
        previewText: msg.text ?? text,
        senderId: msg.senderId,
      );
      _scrollToBottom();
    } else if (mounted) {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
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

  void _cancelPendingImage() {
    setState(() => _pendingImages.clear());
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<void> _confirmSendImages() async {
    if (_pendingImages.isEmpty) return;
    final files = List<File>.from(_pendingImages);
    setState(() {
      _pendingImages.clear();
      _sending = true;
    });
    HapticFeedback.lightImpact();

    for (final file in files) {
      final msg = await ChatService.sendImageMessage(widget.conversation.id, file);
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        context.read<ChatProvider>().touchConversationPreview(
          conversationId: widget.conversation.id,
          previewText: msg.text?.isNotEmpty == true ? msg.text! : '[Image]',
          senderId: msg.senderId,
        );
        _scrollToBottom();
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.conversation.otherUser;
    final isSeller = other?.role == 'seller';
    final displayName = isSeller
        ? (widget.conversation.storeName ?? other?.fullName ?? 'Unknown')
        : (other?.fullName ?? 'Unknown');
    final avatarUrl = isSeller
        ? (widget.conversation.storeLogo ?? other?.avatarUrl)
        : other?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(avatarUrl, displayName, 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _otherOnline ? const Color(0xFF31a24c) : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _otherOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_orderContext != null) ChatOrderContextBanner(orderContext: _orderContext!),
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2.5))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_outlined, size: 44, color: AppColors.muted.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Start the conversation!',
                              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: _groupedMessages.length,
                        itemBuilder: (context, index) {
                          final group = _groupedMessages[index];
                          return _buildMessageGroup(group, index);
                        },
                      ),
          ),

          if (_otherIsTyping) _buildTypingIndicator(),

          // Image preview bar
          if (_pendingImages.isNotEmpty) _buildImagePreview(),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageGroup(List<ChatMessage> group, int groupIndex) {
    final msg = group.first;
    final isSent = msg.senderId == _myId;

    // Date separator: compare with previous group's first message
    bool showDate = groupIndex == 0;
    if (!showDate) {
      final prevGroup = _groupedMessages[groupIndex - 1];
      showDate = _differentDay(prevGroup.first.createdAt, msg.createdAt);
    }

    // Check if this group contains the last sent message for "Seen"
    final lastSentByMe = _messages.lastWhere((m) => m.senderId == _myId, orElse: () => _messages.first);
    final isLastSent = isSent && group.contains(lastSentByMe);

    final isImageGrid = group.length > 1;

    return Column(
      crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                _formatDate(msg.createdAt),
                style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSent) ...[
                _buildAvatar(msg.senderAvatar, msg.senderName ?? '', 24),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isImageGrid ? 170.0 : MediaQuery.of(context).size.width * 0.72),
                  padding: EdgeInsets.symmetric(horizontal: isImageGrid ? 6 : 14, vertical: isImageGrid ? 6 : 9),
                  decoration: BoxDecoration(
                    color: isSent ? const Color(0xFFDCF8C5) : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSent ? 18 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (isImageGrid)
                        _buildImageGrid(group)
                      else if (msg.messageType == 'image' && msg.imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GestureDetector(
                            onTap: () => _viewImage(msg.imageUrl!),
                            child: CachedNetworkImage(
                              imageUrl: msg.imageUrl!,
                              width: 140,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 140,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 140,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        if (msg.text != null && msg.text!.isNotEmpty) const SizedBox(height: 4),
                      ],
                      if (!isImageGrid && msg.text != null && msg.text!.isNotEmpty)
                        Text(
                          msg.text!,
                          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal, height: 1.4),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        _formatTime(msg.createdAt),
                        style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Seen receipt
        if (isLastSent && group.last.isRead)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text(
              'Seen',
              style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _buildImageGrid(List<ChatMessage> imgs) {
    final count = imgs.length;
    final cols = count <= 2 ? count : 3;
    final size = count <= 2 ? 72.0 : 50.0;

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: imgs.map((m) => GestureDetector(
        onTap: () => _viewImage(m.imageUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: m.imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size, height: size,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: size, height: size,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 16),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            '${_typingName ?? 'Someone'} is typing',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 6),
          const _DotsIndicator(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _pendingImages[i],
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => _removePendingImage(i),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_pendingImages.length}/5',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.muted, size: 20),
            onPressed: _cancelPendingImage,
            tooltip: 'Clear all',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Camera button
          IconButton(
            icon: Icon(Icons.camera_alt_outlined, color: AppColors.muted, size: 22),
            onPressed: _sending ? null : _takePhoto,
            tooltip: 'Take photo',
            splashRadius: 20,
          ),
          // Gallery button
          IconButton(
            icon: Icon(Icons.image_outlined, color: AppColors.muted, size: 22),
            onPressed: _sending ? null : _sendImage,
            tooltip: 'Send image',
            splashRadius: 20,
          ),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderStrong, width: 1.2),
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.roseGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _sending ? null : _sendText,
              tooltip: 'Send',
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, double size) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholderAvatar(name, size),
        ),
      );
    }
    return _placeholderAvatar(name, size);
  }

  Widget _placeholderAvatar(String name, double size) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?');

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.roseGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: Colors.white),
      ),
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
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      // Backend already sends Philippine time, no conversion needed
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
      final yesterday = now.subtract(const Duration(days: 1));
      if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(String iso) {
    try {
      // Backend already sends Philippine time, no conversion needed
      final d = DateTime.parse(iso);
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $ampm';
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
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -5).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
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
            offset: Offset(0, _animations[i].value),
            child: child,
          ),
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[500],
            ),
          ),
        );
      }),
    );
  }
}

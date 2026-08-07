import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/chat.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import 'chat_detail_screen.dart';

/// Instagram-style chat inbox listing all conversations.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  Future<void> _refresh() async {
    await context.read<ChatProvider>().loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProv, _) {
          if (chatProv.loading && chatProv.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2.5),
            );
          }

          if (chatProv.conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.deepRose,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.muted.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start chatting with a seller from any product page',
                          style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.deepRose,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: chatProv.conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 76,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final convo = chatProv.conversations[index];
                return _ConversationTile(
                  conversation: convo,
                  onTap: () => _openChat(convo),
                  onDelete: () => _deleteConvo(convo),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openChat(ChatConversation convo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: convo)),
    ).then((_) {
      // Refresh when coming back
      context.read<ChatProvider>().loadConversations();
      context.read<ChatProvider>().refreshUnread();
    });
  }

  Future<void> _deleteConvo(ChatConversation convo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Conversation', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        content: Text('Delete your conversation with ${convo.storeName ?? convo.otherUser?.fullName ?? 'this seller'}?',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ChatProvider>().deleteConversation(convo.id);
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherUser;
    final isSeller = other?.role == 'seller';
    final displayName = isSeller
        ? (conversation.storeName ?? other?.fullName ?? 'Unknown')
        : (other?.fullName ?? 'Unknown');
    final avatarUrl = isSeller
        ? (conversation.storeLogo ?? other?.avatarUrl)
        : other?.avatarUrl;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red[400],
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              _buildAvatar(avatarUrl, displayName),
              const SizedBox(width: 12),
              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.lastMessageText ?? 'No messages yet',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread ? AppColors.charcoal : AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time + unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(conversation.lastMessageAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: hasUnread ? AppColors.deepRose : AppColors.muted,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasUnread)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppColors.deepRose,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholderAvatar(name),
          errorWidget: (_, __, ___) => _placeholderAvatar(name),
        ),
      );
    }
    return _placeholderAvatar(name);
  }

  Widget _placeholderAvatar(String name) {
    final initials = _getInitials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        gradient: AppColors.roseGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      // Backend already sends Philippine time, no conversion needed
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }
}

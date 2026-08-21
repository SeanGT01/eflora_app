/// Model for a chat conversation between customer and seller.
class ChatConversation {
  final int id;
  final int customerId;
  final int sellerId;
  final int storeId;
  final String? storeName;
  final String? storeLogo;
  final ChatUser? otherUser;
  final String? lastMessageText;
  final String? lastMessageAt;
  final int? lastSenderId;
  final int unreadCount;
  final String? createdAt;
  final bool isRiderThread;
  final ChatOrderContext? orderContext;

  const ChatConversation({
    required this.id,
    required this.customerId,
    required this.sellerId,
    required this.storeId,
    this.storeName,
    this.storeLogo,
    this.otherUser,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = 0,
    this.createdAt,
    this.isRiderThread = false,
    this.orderContext,
  });

  ChatConversation copyWith({
    String? lastMessageText,
    String? lastMessageAt,
    int? lastSenderId,
    int? unreadCount,
    bool? isRiderThread,
    ChatOrderContext? orderContext,
  }) => ChatConversation(
    id: id,
    customerId: customerId,
    sellerId: sellerId,
    storeId: storeId,
    storeName: storeName,
    storeLogo: storeLogo,
    otherUser: otherUser,
    lastMessageText: lastMessageText ?? this.lastMessageText,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastSenderId: lastSenderId ?? this.lastSenderId,
    unreadCount: unreadCount ?? this.unreadCount,
    createdAt: createdAt,
    isRiderThread: isRiderThread ?? this.isRiderThread,
    orderContext: orderContext ?? this.orderContext,
  );

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
    id: j['id'] ?? 0,
    customerId: j['customer_id'] ?? 0,
    sellerId: j['seller_id'] ?? 0,
    storeId: j['store_id'] ?? 0,
    storeName: j['store_name'],
    storeLogo: j['store_logo'],
    otherUser: j['other_user'] != null ? ChatUser.fromJson(j['other_user']) : null,
    lastMessageText: j['last_message_text'],
    lastMessageAt: j['last_message_at'],
    lastSenderId: j['last_sender_id'],
    unreadCount: j['unread_count'] ?? 0,
    createdAt: j['created_at'],
    isRiderThread: j['is_rider_thread'] == true,
    orderContext: j['order_context'] is Map<String, dynamic>
        ? ChatOrderContext.fromJson(j['order_context'] as Map<String, dynamic>)
        : null,
  );
}

/// Compact order summary shown above rider↔customer chats.
class ChatOrderContext {
  final int orderId;
  final String orderNumber;
  final String status;
  final String? storeName;
  final double totalAmount;
  final double subtotalAmount;
  final double deliveryFee;
  final int itemCount;
  final List<ChatOrderItem> items;

  const ChatOrderContext({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    this.storeName,
    this.totalAmount = 0,
    this.subtotalAmount = 0,
    this.deliveryFee = 0,
    this.itemCount = 0,
    this.items = const [],
  });

  factory ChatOrderContext.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List? ?? [];
    return ChatOrderContext(
      orderId: j['order_id'] ?? 0,
      orderNumber: j['order_number']?.toString() ?? 'ORD-${j['order_id'] ?? 0}',
      status: j['status']?.toString() ?? '',
      storeName: j['store_name']?.toString(),
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      subtotalAmount: (j['subtotal_amount'] as num?)?.toDouble() ?? 0,
      deliveryFee: (j['delivery_fee'] as num?)?.toDouble() ?? 0,
      itemCount: j['item_count'] ?? rawItems.length,
      items: rawItems
          .whereType<Map>()
          .map((e) => ChatOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
      case 'preparing':
        return 'Preparing';
      case 'done_preparing':
        return 'Ready';
      case 'confirmed':
      case 'picked_up':
        return 'Picked Up';
      case 'on_delivery':
      case 'out_for_delivery':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty ? 'Order' : status.replaceAll('_', ' ');
    }
  }
}

class ChatOrderItem {
  final int id;
  final String name;
  final String? variantName;
  final int quantity;
  final double price;
  final double total;
  final String? imageUrl;
  final List<Map<String, dynamic>> addons;

  const ChatOrderItem({
    required this.id,
    required this.name,
    this.variantName,
    this.quantity = 1,
    this.price = 0,
    this.total = 0,
    this.imageUrl,
    this.addons = const [],
  });

  factory ChatOrderItem.fromJson(Map<String, dynamic> j) => ChatOrderItem(
    id: j['id'] ?? 0,
    name: j['name']?.toString() ?? j['product_name']?.toString() ?? 'Product',
    variantName: j['variant_name']?.toString(),
    quantity: j['quantity'] ?? 1,
    price: (j['price'] as num?)?.toDouble() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    imageUrl: j['image_url']?.toString() ?? j['product_image_url']?.toString(),
    addons: (j['addons'] as List? ?? [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList(),
  );
}

/// Lightweight user info embedded inside a conversation.
class ChatUser {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final String? role;

  const ChatUser({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.role,
  });

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    id: j['id'] ?? 0,
    fullName: j['full_name'] ?? '',
    avatarUrl: j['avatar_url'],
    role: j['role'],
  );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}

/// A single chat message.
class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? senderRole;
  final String messageType; // text, image, deleted
  final String? text;
  final String? imageUrl;
  final String? imagePublicId;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final bool isDeleted;
  final int? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? replyToMessageType;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.senderRole,
    this.messageType = 'text',
    this.text,
    this.imageUrl,
    this.imagePublicId,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.isDeleted = false,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.replyToMessageType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] ?? 0,
    conversationId: j['conversation_id'] ?? 0,
    senderId: j['sender_id'] ?? 0,
    senderName: j['sender_name'],
    senderAvatar: j['sender_avatar'],
    senderRole: j['sender_role'],
    messageType: j['message_type'] ?? 'text',
    text: j['text'],
    imageUrl: j['image_url'],
    imagePublicId: j['image_public_id'],
    isRead: j['is_read'] ?? false,
    readAt: j['read_at'],
    createdAt: j['created_at'] ?? '',
    isDeleted: j['is_deleted'] ?? false,
    replyToId: j['reply_to_id'],
    replyToText: j['reply_to_text'],
    replyToSenderName: j['reply_to_sender_name'],
    replyToMessageType: j['reply_to_message_type'],
  );

  /// Preview label for a quoted reply target.
  String get replyPreviewLabel {
    final t = replyToText?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (replyToMessageType == 'deleted') return 'Message has been deleted';
    if (replyToMessageType == 'image') return '[Image]';
    // Legacy API: image replies returned null text (same as deleted).
    // Prefer [Image] so photo replies don't look deleted.
    return '[Image]';
  }

  bool get isReplyTargetDeleted => replyToMessageType == 'deleted';

  /// Return a copy with soft-delete applied locally.
  ChatMessage asDeleted() => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    senderAvatar: senderAvatar,
    senderRole: senderRole,
    messageType: 'deleted',
    text: null,
    imageUrl: null,
    imagePublicId: null,
    isRead: isRead,
    readAt: readAt,
    createdAt: createdAt,
    isDeleted: true,
    replyToId: replyToId,
    replyToText: replyToText,
    replyToSenderName: replyToSenderName,
    replyToMessageType: replyToMessageType,
  );
}

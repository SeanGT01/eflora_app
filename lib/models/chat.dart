import 'dart:convert';

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

  factory ChatConversation.fromJson(Map<String, dynamic> j) {
    ChatOrderContext? orderContext;
    final oc = j['order_context'];
    if (oc is Map) {
      try {
        orderContext = ChatOrderContext.fromJson(Map<String, dynamic>.from(oc));
      } catch (_) {
        orderContext = null;
      }
    }
    return ChatConversation(
      id: j['id'] ?? 0,
      customerId: j['customer_id'] ?? 0,
      sellerId: j['seller_id'] ?? 0,
      storeId: j['store_id'] ?? 0,
      storeName: j['store_name'],
      storeLogo: j['store_logo'],
      otherUser: j['other_user'] is Map
          ? ChatUser.fromJson(Map<String, dynamic>.from(j['other_user'] as Map))
          : null,
      lastMessageText: j['last_message_text'],
      lastMessageAt: j['last_message_at'],
      lastSenderId: j['last_sender_id'],
      unreadCount: j['unread_count'] is int
          ? (j['unread_count'] as int)
          : int.tryParse(j['unread_count']?.toString() ?? '') ?? 0,
      createdAt: j['created_at'],
      isRiderThread: j['is_rider_thread'] == true,
      orderContext: orderContext,
    );
  }
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
    final rawItems = j['items'] is List ? j['items'] as List : const [];
    final orderId = _asInt(j['order_id'] ?? j['orderId']);
    var number = (j['order_number'] ?? j['orderNumber'])?.toString() ?? '';
    if (number.isEmpty || number.contains('undefined')) {
      number = orderId > 0 ? 'ORD-${orderId.toString().padLeft(5, '0')}' : 'Order';
    }
    return ChatOrderContext(
      orderId: orderId,
      orderNumber: number,
      status: j['status']?.toString() ?? '',
      storeName: (j['store_name'] ?? j['storeName'])?.toString(),
      totalAmount: _asDouble(j['total_amount'] ?? j['totalAmount'] ?? j['total']),
      subtotalAmount: _asDouble(j['subtotal_amount'] ?? j['subtotalAmount']),
      deliveryFee: _asDouble(j['delivery_fee'] ?? j['deliveryFee']),
      itemCount: ChatOrderContext._asInt(j['item_count'] ?? j['itemCount'] ?? rawItems.length),
      items: rawItems
          .whereType<Map>()
          .map((e) {
            try {
              return ChatOrderItem.fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatOrderItem>()
          .toList(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
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

  factory ChatOrderItem.fromJson(Map<String, dynamic> j) {
    final q = ChatOrderContext._asInt(j['quantity'] ?? 1);
    return ChatOrderItem(
      id: ChatOrderContext._asInt(j['id']),
      name: j['name']?.toString() ?? j['product_name']?.toString() ?? 'Product',
      variantName: j['variant_name']?.toString(),
      quantity: q < 1 ? 1 : q,
      price: ChatOrderContext._asDouble(j['price']),
      total: ChatOrderContext._asDouble(j['total']),
      imageUrl: j['image_url']?.toString() ?? j['product_image_url']?.toString(),
      addons: (j['addons'] is List ? j['addons'] as List : const [])
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList(),
    );
  }
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
  final ChatOrderContext? orderCard;
  final CustomQuoteTicketContext? customTicket;

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
    this.orderCard,
    this.customTicket,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawType = j['message_type']?.toString() ?? 'text';
    final customTicket = _customTicketFromJson(j);
    final isTicket = rawType == 'custom_ticket' || customTicket != null;
    return ChatMessage(
      id: j['id'] ?? 0,
      conversationId: j['conversation_id'] ?? 0,
      senderId: j['sender_id'] ?? 0,
      senderName: j['sender_name'],
      senderAvatar: j['sender_avatar'],
      senderRole: j['sender_role'],
      messageType: isTicket
          ? 'custom_ticket'
          : ((j['order_card'] is Map) ? 'order_card' : rawType),
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
      orderCard: _orderCardFromJson(j),
      customTicket: customTicket,
    );
  }

  static CustomQuoteTicketContext? _customTicketFromJson(Map<String, dynamic> j) {
    // 1. Check if j['custom_ticket'] is a Map
    if (j['custom_ticket'] is Map) {
      try {
        return CustomQuoteTicketContext.fromJson(Map<String, dynamic>.from(j['custom_ticket'] as Map));
      } catch (e) {
        print("❌ Error parsing custom_ticket map: $e");
      }
    }

    // 2. Check if j['custom_ticket'] is a String (JSON encoded)
    if (j['custom_ticket'] is String) {
      final str = (j['custom_ticket'] as String).trim();
      if (str.startsWith('{')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is Map) {
            return CustomQuoteTicketContext.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          print("❌ Error parsing stringified custom_ticket: $e");
        }
      }
    }

    // 3. Check if j['text'] contains JSON ticket object
    final text = j['text']?.toString().trim();
    if (text != null && text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (_isTicketMap(map)) {
            return CustomQuoteTicketContext.fromJson(map);
          }
        }
      } catch (_) {}
    }

    // 4. Check if j ITSELF is a ticket object
    if (_isTicketMap(j)) {
      try {
        return CustomQuoteTicketContext.fromJson(j);
      } catch (e) {
        print("❌ Error parsing ticket from root map j: $e");
      }
    }

    return null;
  }

  static bool _isTicketMap(Map map) {
    if (map.containsKey('ticket_number') || map.containsKey('ticketNumber')) return true;
    if (map.containsKey('ticket_id') || map.containsKey('ticketId')) return true;
    final title = map['title']?.toString();
    final price = map['base_price'] ?? map['basePrice'] ?? map['price'];
    if (title != null && price != null && (map.containsKey('store_id') || map.containsKey('conversation_id'))) {
      return true;
    }
    return false;
  }

  static ChatOrderContext? _orderCardFromJson(Map<String, dynamic> j) {
    if (j['order_card'] is Map) {
      final card = ChatOrderContext.fromJson(
          Map<String, dynamic>.from(j['order_card'] as Map));
      if (card.orderId > 0 || card.items.isNotEmpty) return card;
    }
    final text = j['text']?.toString();
    if (text != null && text.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map &&
            (decoded['order_id'] != null || decoded['orderId'] != null)) {
          return ChatOrderContext.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return _fromPreviewText(text);
  }

  static ChatOrderContext? _fromPreviewText(String? text) {
    final match = RegExp(r'ORD-(\d+)', caseSensitive: false).firstMatch(text ?? '');
    if (match == null) return null;
    final orderId = int.tryParse(match.group(1) ?? '') ?? 0;
    if (orderId <= 0) return null;
    return ChatOrderContext(
      orderId: orderId,
      orderNumber: 'ORD-${orderId.toString().padLeft(5, '0')}',
      status: '',
    );
  }

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

  String get orderCardPreview {
    if (messageType != 'order_card') return text ?? '';
    final num = orderCard?.orderNumber;
    return (num != null && num.isNotEmpty) ? 'Order $num' : 'Order details';
  }

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

/// Model for editable support FAQs used in Quick Answers.
class SupportFaq {
  final int id;
  final String question;
  final String answer;
  final bool isActive;

  const SupportFaq({
    required this.id,
    required this.question,
    required this.answer,
    this.isActive = true,
  });

  factory SupportFaq.fromJson(Map<String, dynamic> j) => SupportFaq(
    id: j['id'] ?? 0,
    question: j['question']?.toString() ?? '',
    answer: j['answer']?.toString() ?? '',
    isActive: j['is_active'] != false,
  );
}

/// Model for a Custom Arrangement Request Ticket sent by florist in chat.
class CustomQuoteTicketContext {
  final int id;
  final String ticketNumber;
  final int storeId;
  final String? storeName;
  final String? storeGcashNumber;
  final String? storeGcashQrUrl;
  final bool storeAllowsGcash;
  final bool storeAllowsCod;
  final int customerId;
  final int conversationId;
  final String title;
  final String category;
  final double basePrice;
  final String? inclusions;
  final String? imageUrl;
  final String? imagePublicId;
  final String? createdAt;
  final String? expiresAt;
  final int? remainingSeconds;
  final bool isExpired;
  String status;
  final int? orderId;
  final bool allowDedicationCard;

  CustomQuoteTicketContext({
    required this.id,
    required this.ticketNumber,
    required this.storeId,
    this.storeName,
    this.storeGcashNumber,
    this.storeGcashQrUrl,
    this.storeAllowsGcash = true,
    this.storeAllowsCod = false,
    required this.customerId,
    required this.conversationId,
    required this.title,
    required this.category,
    required this.basePrice,
    this.inclusions,
    this.imageUrl,
    this.imagePublicId,
    this.createdAt,
    this.expiresAt,
    this.remainingSeconds,
    this.isExpired = false,
    this.status = 'pending',
    this.orderId,
    this.allowDedicationCard = true,
  });

  factory CustomQuoteTicketContext.fromJson(Map<String, dynamic> j) {
    double price = ChatOrderContext._asDouble(j['base_price'] ?? j['basePrice'] ?? j['price']);
    String numStr = (j['ticket_number'] ?? j['ticketNumber'] ?? j['ticket_code'] ?? '').toString();
    if (numStr.isEmpty) {
      final tid = ChatOrderContext._asInt(j['id'] ?? j['ticket_id'] ?? j['ticketId']);
      numStr = tid > 0 ? 'CQT-${tid.toString().padLeft(4, '0')}' : 'CQT-0000';
    }

    return CustomQuoteTicketContext(
      id: ChatOrderContext._asInt(j['id'] ?? j['ticket_id'] ?? j['ticketId']),
      ticketNumber: numStr,
      storeId: ChatOrderContext._asInt(j['store_id'] ?? j['storeId']),
      storeName: j['store_name']?.toString() ?? j['storeName']?.toString(),
      storeGcashNumber: j['store_gcash_number']?.toString() ?? j['storeGcashNumber']?.toString(),
      storeGcashQrUrl: j['store_gcash_qr_url']?.toString() ?? j['storeGcashQrUrl']?.toString(),
      storeAllowsGcash: j['store_allows_gcash'] != false && j['storeAllowsGcash'] != false,
      storeAllowsCod: j['store_allows_cod'] == true || j['storeAllowsCod'] == true,
      customerId: ChatOrderContext._asInt(j['customer_id'] ?? j['customerId']),
      conversationId: ChatOrderContext._asInt(j['conversation_id'] ?? j['conversationId']),
      title: (j['title'] ?? 'Custom Arrangement').toString(),
      category: (j['category'] ?? 'bouquets').toString(),
      basePrice: price,
      inclusions: j['inclusions']?.toString(),
      imageUrl: j['image_url']?.toString() ?? j['imageUrl']?.toString(),
      imagePublicId: j['image_public_id']?.toString() ?? j['imagePublicId']?.toString(),
      createdAt: j['created_at']?.toString() ?? j['createdAt']?.toString(),
      expiresAt: j['expires_at']?.toString() ?? j['expiresAt']?.toString(),
      remainingSeconds: j['remaining_seconds'] != null
          ? ChatOrderContext._asInt(j['remaining_seconds'])
          : (j['remainingSeconds'] != null ? ChatOrderContext._asInt(j['remainingSeconds']) : null),
      isExpired: j['is_expired'] == true || j['isExpired'] == true,
      status: (j['status'] ?? 'pending').toString(),
      orderId: (j['order_id'] != null || j['orderId'] != null)
          ? ChatOrderContext._asInt(j['order_id'] ?? j['orderId'])
          : null,
      allowDedicationCard: j['allow_dedication_card'] != false && j['allowDedicationCard'] != false,
    );
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'bouquets':
        return 'Bouquet';
      case 'fresh_flowers':
        return 'Fresh Flowers';
      case 'potted_plants':
        return 'Potted Plants';
      case 'succulents':
        return 'Succulents';
      case 'dried_flowers':
        return 'Dried Flowers';
      case 'stands':
        return 'Flower Stand';
      case 'vases':
        return 'Vase Arrangement';
      default:
        return category.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }
}

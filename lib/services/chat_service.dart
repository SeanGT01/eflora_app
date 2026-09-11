import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import 'api_service.dart';

/// Service class for all chat-related API calls.
class ChatService {
  static String get _base => ApiService.apiRoot.replaceAll('/api/v1', '');
  static String get _api => '${ApiService.apiRoot}/chat';


  static Future<Map<String, String>> _headers() async {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = await ApiService.getToken();
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ══════════════════════════════════════════════════════════════════════

  static List<ChatConversation> _conversationsCache = [];
  static ChatConversation? _adminSupportConvoCache;
  static List<Map<String, dynamic>> _deliverableStoresCache = [];

  /// Get conversations synchronously from memory cache if available (0ms instant access).
  static List<ChatConversation> getCachedConversationsSync() {
    if (_conversationsCache.isNotEmpty) {
      return List<ChatConversation>.from(_conversationsCache);
    }
    return const [];
  }

  /// Get cached Admin/Support conversation if available in memory (0ms instant access).
  static ChatConversation? getSupportConversationSync() {
    if (_adminSupportConvoCache != null) return _adminSupportConvoCache;
    final match = _conversationsCache.where((c) => c.otherUser?.role == 'admin').toList();
    if (match.isNotEmpty) return match.first;
    return null;
  }

  /// Preload conversations, stores, support convo, and message histories from SharedPreferences into RAM on startup.
  static Future<void> preloadCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Deliverable stores
      final storesStr = prefs.getString('chat_deliverable_stores');
      if (storesStr != null && storesStr.isNotEmpty) {
        final rawStores = jsonDecode(storesStr) as List? ?? [];
        final parsed = List<Map<String, dynamic>>.from(
          rawStores.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
        if (parsed.isNotEmpty) _deliverableStoresCache = parsed;
      }

      // 2. Conversations list
      final convosStr = prefs.getString('chat_conversations_cache');
      if (convosStr != null && convosStr.isNotEmpty) {
        final rawConvos = jsonDecode(convosStr) as List? ?? [];
        final parsedConvos = rawConvos
            .whereType<Map>()
            .map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        if (parsedConvos.isNotEmpty) {
          _conversationsCache = parsedConvos;
          final adminMatch = parsedConvos.where((c) => c.otherUser?.role == 'admin').toList();
          if (adminMatch.isNotEmpty) _adminSupportConvoCache = adminMatch.first;
        }
      }

      // 3. Support conversation cache
      final supportStr = prefs.getString('chat_admin_support_convo');
      if (supportStr != null && supportStr.isNotEmpty) {
        final rawSupport = jsonDecode(supportStr);
        if (rawSupport is Map) {
          _adminSupportConvoCache = ChatConversation.fromJson(Map<String, dynamic>.from(rawSupport));
        }
      }

      // 4. Message histories for cached conversations
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('chat_history_')) {
          final idStr = key.replaceFirst('chat_history_', '');
          final convoId = int.tryParse(idStr);
          if (convoId != null && convoId > 0) {
            final str = prefs.getString(key);
            if (str != null && str.isNotEmpty) {
              final list = jsonDecode(str) as List? ?? [];
              final parsed = list
                  .whereType<Map>()
                  .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
                  .toList();
              if (parsed.isNotEmpty) {
                _memoryCache[convoId] = parsed;
              }
            }
          }
        }
      }
    } catch (e) {
      print('ChatService.preloadCaches error: $e');
    }
  }

  /// Get conversations from local persistent storage.
  static Future<List<ChatConversation>> getLocalConversations() async {
    if (_conversationsCache.isNotEmpty) {
      return List<ChatConversation>.from(_conversationsCache);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('chat_conversations_cache');
      if (str != null) {
        final list = jsonDecode(str) as List? ?? [];
        final parsed = list
            .whereType<Map>()
            .map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        if (parsed.isNotEmpty) {
          _conversationsCache = parsed;
          final adminMatch = parsed.where((c) => c.otherUser?.role == 'admin').toList();
          if (adminMatch.isNotEmpty) _adminSupportConvoCache = adminMatch.first;
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ChatConversation>> getConversations() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/conversations'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          list = decoded['conversations'] as List? ?? [];
        }
        final parsed = list.map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j))).toList();
        _conversationsCache = parsed;
        final adminMatch = parsed.where((c) => c.otherUser?.role == 'admin').toList();
        if (adminMatch.isNotEmpty) _adminSupportConvoCache = adminMatch.first;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('chat_conversations_cache', jsonEncode(list));
        } catch (_) {}
        return parsed;
      }
      if (_conversationsCache.isNotEmpty) return List<ChatConversation>.from(_conversationsCache);
      return [];
    } catch (e) {
      print('❌ ChatService.getConversations error: $e');
      if (_conversationsCache.isNotEmpty) return List<ChatConversation>.from(_conversationsCache);
      return [];
    }
  }

  /// Create or get an existing conversation with a store.
  static Future<ChatConversation?> getOrCreateConversation(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/conversations'),
        headers: await _headers(),
        body: jsonEncode({'store_id': storeId}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['conversation'] != null) {
        final convo = ChatConversation.fromJson(data['conversation']);
        final idx = _conversationsCache.indexWhere((c) => c.id == convo.id);
        if (idx >= 0) {
          _conversationsCache[idx] = convo;
        } else {
          _conversationsCache.insert(0, convo);
        }
        return convo;
      }
      return null;
    } catch (e) {
      print('❌ ChatService.getOrCreateConversation error: $e');
      return null;
    }
  }

  /// Rider flow: open/create conversation for a specific assigned order.
  static Future<ChatConversation?> getOrCreateRiderConversation(int orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/conversations/rider-order'),
        headers: await _headers(),
        body: jsonEncode({'order_id': orderId}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (data is Map && data['conversation'] is Map) {
        final convo = ChatConversation.fromJson(
            Map<String, dynamic>.from(data['conversation'] as Map));
        final idx = _conversationsCache.indexWhere((c) => c.id == convo.id);
        if (idx >= 0) {
          _conversationsCache[idx] = convo;
        } else {
          _conversationsCache.insert(0, convo);
        }
        return convo;
      }
      return null;
    } catch (e) {
      print('❌ ChatService.getOrCreateRiderConversation error: $e');
      return null;
    }
  }

  /// Open or create support conversation with an admin account.
  static Future<ChatConversation?> getOrCreateSupportConversation() async {
    try {
      final res = await http.post(
        Uri.parse('$_api/conversations/support'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (data is Map && data['conversation'] is Map) {
        final convo = ChatConversation.fromJson(
            Map<String, dynamic>.from(data['conversation'] as Map));
        _adminSupportConvoCache = convo;
        final idx = _conversationsCache.indexWhere((c) => c.id == convo.id || c.otherUser?.role == 'admin');
        if (idx >= 0) {
          _conversationsCache[idx] = convo;
        } else {
          _conversationsCache.insert(0, convo);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('chat_admin_support_convo', jsonEncode(data['conversation']));
        } catch (_) {}
        return convo;
      }
      return _adminSupportConvoCache;
    } catch (e) {
      print('❌ ChatService.getOrCreateSupportConversation error: $e');
      return _adminSupportConvoCache;
    }
  }

  /// Fetch active FAQs for Quick Answers.
  static Future<List<SupportFaq>> getSupportFaqs() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/support-faqs'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['faqs'] as List? ?? [];
        return list
            .whereType<Map>()
            .map((j) => SupportFaq.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ ChatService.getSupportFaqs error: $e');
      return [];
    }
  }

  /// Get a single conversation by ID (includes rider order_context when applicable).
  static Future<ChatConversation?> getConversation(int convoId, {int? orderId}) async {
    try {
      final qs = orderId != null ? '?order_id=$orderId' : '';
      final res = await http.get(
        Uri.parse('$_api/conversations/$convoId$qs'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final convoJson = data['conversation'];
        if (convoJson is Map<String, dynamic>) {
          // Prefer nested order_context; fall back to top-level if present.
          if (convoJson['order_context'] == null && data['order_context'] != null) {
            convoJson['order_context'] = data['order_context'];
          }
          final convo = ChatConversation.fromJson(convoJson);
          final idx = _conversationsCache.indexWhere((c) => c.id == convo.id);
          if (idx >= 0) {
            _conversationsCache[idx] = convo;
          } else {
            _conversationsCache.insert(0, convo);
          }
          return convo;
        }
      }
      return null;
    } catch (e) {
      print('❌ ChatService.getConversation error: $e');
      return null;
    }
  }

  /// Soft-delete a conversation.
  static Future<bool> deleteConversation(int convoId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_api/conversations/$convoId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        _conversationsCache.removeWhere((c) => c.id == convoId);
        _memoryCache.remove(convoId);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('chat_history_$convoId');
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      print('❌ ChatService.deleteConversation error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════

  static final Map<int, List<ChatMessage>> _memoryCache = {};

  /// Get messages synchronously from memory cache if available (0ms instant access).
  static List<ChatMessage> getCachedMessagesSync(int convoId) {
    final list = _memoryCache[convoId];
    if (list != null && list.isNotEmpty) {
      return List<ChatMessage>.from(list);
    }
    return const [];
  }

  /// Update the in-memory cache and persist locally.
  static void updateMemoryCache(int convoId, List<ChatMessage> messages) {
    _memoryCache[convoId] = List<ChatMessage>.from(messages);
  }

  /// Append a newly sent or received message to cache.
  static void appendMessageToCache(int convoId, ChatMessage message) {
    final current = _memoryCache[convoId] ?? [];
    if (!current.any((m) => m.id == message.id)) {
      final updated = List<ChatMessage>.from(current)..add(message);
      _memoryCache[convoId] = updated;
    }
  }

  static Future<List<ChatMessage>> getLocalMessages(int convoId) async {
    if (_memoryCache.containsKey(convoId) && _memoryCache[convoId]!.isNotEmpty) {
      return List<ChatMessage>.from(_memoryCache[convoId]!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('chat_history_$convoId');
      if (str != null) {
        final list = jsonDecode(str) as List? ?? [];
        final parsed = list
            .whereType<Map>()
            .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        if (parsed.isNotEmpty) {
          _memoryCache[convoId] = parsed;
        }
        return parsed;
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// Fetch message history for a conversation (paginated, newest first).
  static Future<List<ChatMessage>> getMessages(int convoId, {int page = 1, int perPage = 30}) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/conversations/$convoId/messages?page=$page&per_page=$perPage'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          list = decoded['messages'] as List? ?? [];
        }
        final parsed = list.map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j))).toList();
        if (page == 1) {
          _memoryCache[convoId] = parsed;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('chat_history_$convoId', jsonEncode(list));
          } catch (e) {
            // ignore
          }
        }
        return parsed;
      }
      return [];
    } catch (e) {
      print('❌ ChatService.getMessages error: $e');
      return [];
    }
  }

  /// Send a text message.
  static Future<ChatMessage?> sendMessage(int convoId, String text, {int? replyToId}) async {
    try {
      final body = <String, dynamic>{'text': text, 'message_type': 'text'};
      if (replyToId != null) body['reply_to_id'] = replyToId;
      final res = await http.post(
        Uri.parse('$_api/conversations/$convoId/messages'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ChatMessage.fromJson(data['message']);
      }
      return null;
    } catch (e) {
      print('❌ ChatService.sendMessage error: $e');
      return null;
    }
  }

  /// Share a one-time order-details card in a rider↔customer thread.
  static Future<ChatMessage?> sendOrderCard(int convoId, int orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/conversations/$convoId/messages'),
        headers: await _headers(),
        body: jsonEncode({'message_type': 'order_card', 'order_id': orderId}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = data['message'];
        if (msg is Map<String, dynamic>) return ChatMessage.fromJson(msg);
        if (msg is Map) {
          return ChatMessage.fromJson(Map<String, dynamic>.from(msg));
        }
      }
      return null;
    } catch (e) {
      print('❌ ChatService.sendOrderCard error: $e');
      return null;
    }
  }

  /// Send an image message.
  static Future<ChatMessage?> sendImageMessage(int convoId, File imageFile, {String? caption}) async {
    try {
      final token = await ApiService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_api/conversations/$convoId/messages/image'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      if (caption != null && caption.isNotEmpty) {
        request.fields['text'] = caption;
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = jsonDecode(resBody) as Map<String, dynamic>;
        return ChatMessage.fromJson(data['message']);
      }
      return null;
    } catch (e) {
      print('❌ ChatService.sendImageMessage error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // READ RECEIPTS & UNREAD
  // ══════════════════════════════════════════════════════════════════════

  /// Mark all messages as read in a conversation.
  static Future<bool> markAsRead(int convoId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/conversations/$convoId/read'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      print('❌ ChatService.markAsRead error: $e');
      return false;
    }
  }

  /// Get total unread message count.
  static Future<int> getUnreadCount() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/unread-count'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ ChatService.getUnreadCount error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ONLINE STATUS
  // ══════════════════════════════════════════════════════════════════════

  /// Check if a user is currently online (active session).
  static Future<bool> isUserOnline(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/users/$userId/online'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['is_online'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Ping the server while the app is in the foreground so Online status
  /// reflects an active logged-in session (not merely a valid JWT).
  static Future<void> sendPresenceHeartbeat() async {
    try {
      await http
          .post(
            Uri.parse('$_api/presence/heartbeat'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Batch-check which users are currently online (active session).
  static Future<Map<int, bool>> getPresenceStatus(List<int> userIds) async {
    final ids = userIds.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final res = await http
          .post(
            Uri.parse('$_api/presence/status'),
            headers: await _headers(),
            body: jsonEncode({'user_ids': ids}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final online = data['online'];
      if (online is! Map) return {};
      final out = <int, bool>{};
      online.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null) out[id] = value == true;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TYPING INDICATOR
  // ══════════════════════════════════════════════════════════════════════

  /// Signal that the current user is typing.
  static Future<void> sendTyping(int convoId) async {
    try {
      await http.post(
        Uri.parse('$_api/conversations/$convoId/typing'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Check who is typing in a conversation.
  static Future<List<Map<String, dynamic>>> getTyping(int convoId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/conversations/$convoId/typing'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['typing'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // STORE SEARCH & DELIVERABLE STORES (for new-conversation flow)
  // ══════════════════════════════════════════════════════════════════════

  /// Get deliverable stores synchronously from memory cache (0ms instant access).
  static List<Map<String, dynamic>> getCachedDeliverableStoresSync() {
    if (_deliverableStoresCache.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_deliverableStoresCache);
    }
    return const [];
  }

  /// Get deliverable stores from local persistent storage.
  static Future<List<Map<String, dynamic>>> getLocalDeliverableStores() async {
    if (_deliverableStoresCache.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_deliverableStoresCache);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('chat_deliverable_stores');
      if (str != null) {
        final raw = jsonDecode(str) as List? ?? [];
        final parsed = List<Map<String, dynamic>>.from(
          raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
        if (parsed.isNotEmpty) {
          _deliverableStoresCache = parsed;
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  /// Fetch stores that can deliver to the customer's address.
  static Future<List<Map<String, dynamic>>> getDeliverableStores() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/v1/customer/stores?include_outside_location=1'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(
          raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
        // Prioritize stores that can deliver to customer
        final deliverable = list.where((s) => s['can_deliver_to_customer'] == true).toList();
        final result = deliverable.isNotEmpty ? deliverable : list;
        _deliverableStoresCache = result;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('chat_deliverable_stores', jsonEncode(result));
        } catch (_) {}
        return result;
      }
      return [];
    } catch (e) {
      print('❌ ChatService.getDeliverableStores error: $e');
      return [];
    }
  }

  /// Fetch all stores for search / new conversation.
  static Future<List<Map<String, dynamic>>> searchStores(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/v1/customer/stores?include_outside_location=1'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> stores = jsonDecode(res.body);
        final mapped = List<Map<String, dynamic>>.from(
          stores.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
        if (query.isEmpty) return mapped.take(20).toList();
        final q = query.toLowerCase();
        return mapped
            .where((s) => (s['name'] ?? '').toString().toLowerCase().contains(q))
            .take(10)
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ ChatService.searchStores error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DELETE MESSAGE
  // ══════════════════════════════════════════════════════════════════════

  /// Soft-delete a message (returns the updated message).
  static Future<ChatMessage?> deleteMessage(int convoId, int messageId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_api/conversations/$convoId/messages/$messageId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ChatMessage.fromJson(data['message']);
      }
      return null;
    } catch (e) {
      print('❌ ChatService.deleteMessage error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // CUSTOM QUOTE TICKETS
  // ══════════════════════════════════════════════════════════════════════

  /// Create a bespoke arrangement quote ticket in a conversation (Florist only).
  static Future<Map<String, dynamic>> createCustomTicket({
    required int conversationId,
    required String title,
    required String category,
    required double basePrice,
    String? inclusions,
    File? imageFile,
    bool allowDedicationCard = true,
  }) async {
    try {
      final uri = Uri.parse('$_api/conversations/$conversationId/custom-ticket');
      final req = http.MultipartRequest('POST', uri);
      final t = await ApiService.getToken();
      if (t != null) req.headers['Authorization'] = 'Bearer $t';

      req.fields['title'] = title;
      req.fields['category'] = category;
      req.fields['base_price'] = basePrice.toStringAsFixed(2);
      req.fields['allow_dedication_card'] = allowDedicationCard.toString();
      if (inclusions != null && inclusions.trim().isNotEmpty) {
        req.fields['inclusions'] = inclusions.trim();
      }

      if (imageFile != null && await imageFile.exists()) {
        final ext = imageFile.path.split('.').last.toLowerCase();
        req.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: 'custom_arrangement_${DateTime.now().millisecondsSinceEpoch}.$ext',
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 40));
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 || res.statusCode == 200) {
        return {
          'success': true,
          'ticket': data['ticket'] != null
              ? CustomQuoteTicketContext.fromJson(Map<String, dynamic>.from(data['ticket']))
              : null,
          'message': data['message'] != null
              ? ChatMessage.fromJson(Map<String, dynamic>.from(data['message']))
              : null,
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Failed to create quote ticket'};
    } catch (e) {
      print('❌ ChatService.createCustomTicket error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get live details of a custom ticket by ID.
  static Future<CustomQuoteTicketContext?> getCustomTicket(int ticketId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/custom-ticket/$ticketId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ticket'] is Map) {
          return CustomQuoteTicketContext.fromJson(Map<String, dynamic>.from(data['ticket']));
        }
      }
      return null;
    } catch (e) {
      print('❌ ChatService.getCustomTicket error: $e');
      return null;
    }
  }

  /// Fetch active in-stock add-ons for the store.
  static Future<List<Map<String, dynamic>>> getStoreAddons(int storeId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/stores/$storeId/addons'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['addons'] as List? ?? [];
        return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
      return [];
    } catch (e) {
      print('❌ ChatService.getStoreAddons error: $e');
      return [];
    }
  }

  /// Checkout a custom arrangement ticket (Customer action).
  static Future<Map<String, dynamic>> checkoutCustomTicket({
    required int ticketId,
    required String deliveryAddress,
    int? deliveryAddressId,
    double? latitude,
    double? longitude,
    String? deliveryNotes,
    String? requestedDate,
    String? requestedTime,
    String? dedicationCard,
    required String paymentMethod, // 'cod' or 'gcash'
    File? receiptFile,
    List<Map<String, dynamic>> addons = const [],
  }) async {
    try {
      final uri = Uri.parse('$_api/custom-ticket/$ticketId/checkout');
      final req = http.MultipartRequest('POST', uri);
      final t = await ApiService.getToken();
      if (t != null) req.headers['Authorization'] = 'Bearer $t';

      req.fields['delivery_address'] = deliveryAddress;
      if (deliveryAddressId != null) req.fields['delivery_address_id'] = deliveryAddressId.toString();
      if (latitude != null) req.fields['customer_latitude'] = latitude.toString();
      if (longitude != null) req.fields['customer_longitude'] = longitude.toString();
      if (deliveryNotes != null && deliveryNotes.trim().isNotEmpty) {
        req.fields['delivery_notes'] = deliveryNotes.trim();
      }
      if (requestedDate != null && requestedDate.isNotEmpty) {
        req.fields['requested_delivery_date'] = requestedDate;
      }
      if (requestedTime != null && requestedTime.isNotEmpty) {
        req.fields['requested_delivery_time'] = requestedTime;
      }
      if (dedicationCard != null && dedicationCard.trim().isNotEmpty) {
        req.fields['dedication_card'] = dedicationCard.trim();
      }
      req.fields['payment_method'] = paymentMethod;

      if (addons.isNotEmpty) {
        req.fields['addons'] = jsonEncode(addons);
      }

      if (paymentMethod == 'gcash' && receiptFile != null && await receiptFile.exists()) {
        final ext = receiptFile.path.split('.').last.toLowerCase();
        req.files.add(await http.MultipartFile.fromPath(
          'receipt',
          receiptFile.path,
          filename: 'gcash_receipt_${DateTime.now().millisecondsSinceEpoch}.$ext',
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 40));
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 201 || res.statusCode == 200) {
        return {
          'success': true,
          'order_id': data['order_id'],
          'total_amount': data['total_amount'],
          'payment_method': data['payment_method'],
          'message': data['message'],
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Checkout failed'};
    } catch (e) {
      print('❌ ChatService.checkoutCustomTicket error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel a COD custom ticket order (Seller & Seller Admin only).
  static Future<Map<String, dynamic>> cancelCodOrder({
    required int orderId,
    String? reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/orders/$orderId/cancel-cod'),
        headers: await _headers(),
        body: jsonEncode({'reason': reason ?? 'Cancelled by seller upon customer request'}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Order cancelled successfully'};
      }
      return {'success': false, 'error': data['error'] ?? 'Could not cancel COD order'};
    } catch (e) {
      print('❌ ChatService.cancelCodOrder error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if a store delivers to a customer address (radius, customzone, municipality).
  static Future<Map<String, dynamic>> checkStoreDelivery({
    required int storeId,
    int? addressId,
    double subtotal = 100.0,
  }) async {
    try {
      var uriStr = '$_api/stores/$storeId/check-delivery?subtotal=$subtotal';
      if (addressId != null) uriStr += '&address_id=$addressId';
      final res = await http.get(
        Uri.parse(uriStr),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'can_deliver': false, 'reason': 'Failed to verify delivery coverage.'};
    } catch (e) {
      print('❌ ChatService.checkStoreDelivery error: $e');
      return {'can_deliver': false, 'reason': 'Error checking store delivery coverage.'};
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import 'api_service.dart';

/// Service class for all chat-related API calls.
class ChatService {
  static const String _base = 'https://eflora-system-production.up.railway.app';
  static const String _api = '$_base/api/v1/chat';

  static Future<Map<String, String>> _headers() async {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = await ApiService.getToken();
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ══════════════════════════════════════════════════════════════════════

  /// Fetch all conversations for the current user.
  static Future<List<ChatConversation>> getConversations() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/conversations'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['conversations'] as List? ?? [];
        return list.map((j) => ChatConversation.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('❌ ChatService.getConversations error: $e');
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
        return ChatConversation.fromJson(data['conversation']);
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

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['conversation'] != null) {
        return ChatConversation.fromJson(data['conversation']);
      }
      return null;
    } catch (e) {
      print('❌ ChatService.getOrCreateRiderConversation error: $e');
      return null;
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
          return ChatConversation.fromJson(convoJson);
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
      return res.statusCode == 200;
    } catch (e) {
      print('❌ ChatService.deleteConversation error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════

  /// Fetch message history for a conversation (paginated, newest first).
  static Future<List<ChatMessage>> getMessages(int convoId, {int page = 1, int perPage = 30}) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/conversations/$convoId/messages?page=$page&per_page=$perPage'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['messages'] as List? ?? [];
        return list.map((j) => ChatMessage.fromJson(j)).toList();
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

  /// Check if a user is currently online.
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
  // STORE SEARCH (for new-conversation flow)
  // ══════════════════════════════════════════════════════════════════════

  /// Fetch all stores for search / new conversation.
  static Future<List<Map<String, dynamic>>> searchStores(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/v1/customer/stores'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> stores = jsonDecode(res.body);
        if (query.isEmpty) return List<Map<String, dynamic>>.from(stores.take(20));
        final q = query.toLowerCase();
        return List<Map<String, dynamic>>.from(
          stores.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(q)).take(10),
        );
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
}

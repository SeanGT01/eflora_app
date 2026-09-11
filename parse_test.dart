import 'dart:convert';

class ChatOrderContext {
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
}

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
    return CustomQuoteTicketContext(
      id: ChatOrderContext._asInt(j['id'] ?? j['ticket_id']),
      ticketNumber: (j['ticket_number'] ?? j['ticketNumber'] ?? 'CQT-0000').toString(),
      storeId: ChatOrderContext._asInt(j['store_id'] ?? j['storeId']),
      storeName: j['store_name']?.toString(),
      storeGcashNumber: j['store_gcash_number']?.toString(),
      storeGcashQrUrl: j['store_gcash_qr_url']?.toString(),
      storeAllowsGcash: j['store_allows_gcash'] != false,
      storeAllowsCod: j['store_allows_cod'] == true,
      customerId: ChatOrderContext._asInt(j['customer_id'] ?? j['customerId']),
      conversationId: ChatOrderContext._asInt(j['conversation_id'] ?? j['conversationId']),
      title: (j['title'] ?? 'Custom Arrangement').toString(),
      category: (j['category'] ?? 'bouquets').toString(),
      basePrice: ChatOrderContext._asDouble(j['base_price'] ?? j['basePrice']),
      inclusions: j['inclusions']?.toString(),
      imageUrl: j['image_url']?.toString() ?? j['imageUrl']?.toString(),
      imagePublicId: j['image_public_id']?.toString(),
      createdAt: j['created_at']?.toString(),
      expiresAt: j['expires_at']?.toString(),
      remainingSeconds: j['remaining_seconds'] != null ? ChatOrderContext._asInt(j['remaining_seconds']) : null,
      isExpired: j['is_expired'] == true,
      status: (j['status'] ?? 'pending').toString(),
      orderId: j['order_id'] != null ? ChatOrderContext._asInt(j['order_id']) : null,
      allowDedicationCard: j['allow_dedication_card'] != false && j['allowDedicationCard'] != false,
    );
  }
}

void main() {
  String jsonStr = """
  {"id": 11, "ticket_id": 11, "ticket_number": "CQT-20260910-0011", "store_id": 15, "store_name": "E-flora", "store_logo": "url", "store_allows_cod": true, "store_allows_gcash": true, "store_gcash_number": null, "store_gcash_qr_url": "url", "customer_id": 198, "customer_name": "Kristina Kosh", "conversation_id": 62, "title": "Purple Bouquet", "category": "bouquets", "base_price": 120.0, "inclusions": "Wrapper included", "image_url": "url", "allow_dedication_card": false, "expires_at": "2026-09-11T07:10:59.078195+08:00", "expires_at_raw": "2026-09-10T23:10:59.078195", "remaining_seconds": 14399, "status": "pending", "is_expired": false, "order_id": null, "created_at": "2026-09-11T03:10:59.133726+08:00"}
  """;
  
  try {
    Map<String, dynamic> j = jsonDecode(jsonStr);
    CustomQuoteTicketContext ctx = CustomQuoteTicketContext.fromJson(j);
    print("Success: ${ctx.id}");
  } catch (e, stack) {
    print("Error: $e");
    print(stack);
  }
}

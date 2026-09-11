import 'dart:convert';
import 'lib/models/chat.dart';

void main() {
  final jsonString = '''
  {
    "id": 10,
    "ticket_id": 10,
    "ticket_number": "CQT-20260910-0010",
    "store_id": 15,
    "store_name": "E-flora",
    "store_logo": "https://res.cloudinary.com/dgyq49vi2/image/upload/v1788634285/e-flowers/store_logos/logo_634284_c3bb7a8c.png",
    "store_allows_cod": true,
    "store_allows_gcash": false,
    "store_gcash_number": "09456787445",
    "store_gcash_qr_url": "https://res.cloudinary.com/dgyq49vi2/image/upload/v1788634313/e-flowers/gcash_qr/7d3f75e277364ef5b46b423e784be1_634314_1b11c6d1.jpg",
    "customer_id": 198,
    "customer_name": "Kristina Kosh",
    "conversation_id": 62,
    "title": "Yellow and Green Tulips",
    "category": "bouquets",
    "base_price": 100.0,
    "inclusions": null,
    "image_url": "https://res.cloudinary.com/dgyq49vi2/image/upload/v1789045109/e-flowers/custom-tickets/qvvkgeeuqx6thzdbumn.jpg",
    "allow_dedication_card": false,
    "expires_at": "2026-09-11T00:58:29.992501+08:00"
  }
  ''';

  try {
    final decoded = jsonDecode(jsonString);
    final ctx = CustomQuoteTicketContext.fromJson(Map<String, dynamic>.from(decoded));
    print('SUCCESS: \${ctx.ticketNumber}');
  } catch (e, stack) {
    print('ERROR: \$e');
    print(stack);
  }
}

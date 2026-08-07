import 'package:flutter/material.dart';

int _safeInt(dynamic v) => v is int ? v : v is String ? int.parse(v) : (v as num?)?.toInt() ?? 0;
double _safeDbl(dynamic v) => v is double ? v : v is int ? v.toDouble() : v is String ? double.parse(v) : (v as num?)?.toDouble() ?? 0.0;

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final String? variantName;
  final int? variantId;
  final int quantity;
  final double price;
  final String? imageUrl;

  const OrderItem({
    required this.id, required this.productId, required this.productName,
    this.variantName, this.variantId,
    required this.quantity, required this.price, this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    // Try multiple possible field names for image URL
    final imageUrl = j['image_url'] ?? j['product_image_url'] ?? j['image'] ?? j['thumbnail_url'];
    return OrderItem(
      id: _safeInt(j['id']),
      productId: _safeInt(j['product_id']),
      productName: j['product_name'] ?? j['name'] ?? '',
      variantName: j['variant_name'] ?? j['variant'],
      variantId: j['variant_id'] != null ? _safeInt(j['variant_id']) : null,
      quantity: _safeInt(j['quantity']),
      price: _safeDbl(j['price']),
      imageUrl: imageUrl,
    );
  }

  /// Get display name: shows "Product - Variant" if variant exists, otherwise just product name
  String get displayName {
    if (variantName != null && variantName!.isNotEmpty) {
      return '$productName - $variantName';
    }
    return productName;
  }
}

class Order {
  final int id;
  final String status;
  final double subtotalAmount;
  final double totalAmount;
  final double deliveryFee;
  final String? storeName;
  final List<OrderItem> items;
  final DateTime? createdAt;
  final String? riderName;
  final String? paymentProofUrl;
  final String? deliveryProofUrl;
  final String? deliveryProof2Url;
  final String? donePreparingProofUrl;
  final String? paymentMethod;
  final String? paymentStatus;
  
  // Status timeline timestamps
  final DateTime? pendingAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? donePreparingAt;
  final DateTime? confirmedAt;
  final DateTime? deliveredAt;

  const Order({
    required this.id, required this.status, required this.subtotalAmount, required this.totalAmount,
    required this.deliveryFee,
    this.storeName, required this.items, this.createdAt, this.riderName,
    this.paymentProofUrl, this.deliveryProofUrl, this.deliveryProof2Url, this.donePreparingProofUrl,
    this.paymentMethod, this.paymentStatus,
    this.pendingAt, this.acceptedAt, this.preparingAt, this.donePreparingAt,
    this.confirmedAt, this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? [])
        .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return Order(
      id: _safeInt(j['id']),
      status: j['status'] ?? 'pending',
      subtotalAmount: _safeDbl(j['subtotal_amount']),
      totalAmount: _safeDbl(j['total_amount']),
      deliveryFee: _safeDbl(j['delivery_fee']),
      storeName: j['store_name'],
      items: items,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      riderName: j['rider_name'],
      paymentProofUrl: j['payment_proof_url'],
      deliveryProofUrl: j['delivery_proof_url'],
      deliveryProof2Url: j['delivery_proof_2_url'],
      donePreparingProofUrl: j['done_preparing_proof_url'],
      paymentMethod: j['payment_method']?.toString(),
      paymentStatus: j['payment_status']?.toString(),
      pendingAt: j['pending_at'] != null ? DateTime.tryParse(j['pending_at']) : null,
      acceptedAt: j['accepted_at'] != null ? DateTime.tryParse(j['accepted_at']) : null,
      preparingAt: j['preparing_at'] != null ? DateTime.tryParse(j['preparing_at']) : null,
      donePreparingAt: j['done_preparing_at'] != null ? DateTime.tryParse(j['done_preparing_at']) : null,
      confirmedAt: j['confirmed_at'] != null ? DateTime.tryParse(j['confirmed_at']) : null,
      deliveredAt: j['delivered_at'] != null ? DateTime.tryParse(j['delivered_at']) : null,
    );
  }

  bool get _isCod {
    final method = (paymentMethod ?? '').toLowerCase().trim();
    final payStatus = (paymentStatus ?? '').toLowerCase().trim();
    return method == 'cod' ||
        payStatus == 'cod_pending' ||
        payStatus == 'cod_approved';
  }

  /// Display grouping aligned with website purchase history tabs.
  /// Keys: pending | processing | on_delivery | delivered | completed | cancelled
  String get displayKey {
    final payStatus = (paymentStatus ?? '').toLowerCase().trim();

    if (status == 'cancelled') return 'cancelled';
    if (status == 'delivered') return 'delivered';
    if (status == 'completed') return 'completed';
    if (status == 'on_delivery') return 'on_delivery';
    if (status == 'done_preparing') return 'processing';

    // COD awaiting seller confirmation → To Ship (not To Pay)
    if (_isCod && (status == 'pending' || payStatus == 'cod_pending')) {
      return 'processing';
    }
    if (_isCod &&
        (payStatus == 'cod_approved' ||
            status == 'accepted' ||
            status == 'preparing')) {
      return 'processing';
    }

    if (payStatus == 'pending_verification') return 'processing';
    if (status == 'accepted' ||
        status == 'preparing' ||
        status == 'confirmed' ||
        payStatus == 'verified') {
      return 'processing';
    }

    return 'pending';
  }

  /// Text colour of the status pill, matching the web badge palette.
  Color get statusColor {
    switch (displayKey) {
      case 'pending':    return const Color(0xFFA06030);
      case 'processing': return const Color(0xFF6A4A9A);
      case 'on_delivery':return const Color(0xFFA04060);
      case 'delivered':  return const Color(0xFF3F6B4E);
      case 'completed':  return const Color(0xFFA04068);
      case 'cancelled':  return const Color(0xFF9B1C1C);
      default:           return const Color(0xFF9A8D85);
    }
  }

  /// Fill of the status pill.
  Color get statusBackgroundColor {
    switch (displayKey) {
      case 'pending':    return const Color(0x73FFD2B4);
      case 'processing': return const Color(0x66D2BEF0);
      case 'delivered':  return const Color(0x80C8E6D2);
      case 'on_delivery':return const Color(0x66FFBED2);
      case 'completed':  return const Color(0x2ED878A0);
      case 'cancelled':  return const Color(0x1FC24E68);
      default:           return const Color(0x8CFFFFFF);
    }
  }

  /// Hairline border of the status pill.
  Color get statusBorderColor {
    switch (displayKey) {
      case 'pending':    return const Color(0x66E8A078);
      case 'processing': return const Color(0x59B070C8);
      case 'delivered':  return const Color(0x597A9E7E);
      case 'on_delivery':return const Color(0x4DC24E68);
      case 'completed':  return const Color(0x47C24E68);
      case 'cancelled':  return const Color(0x40C24E68);
      default:           return const Color(0xB3FFFFFF);
    }
  }

  String get statusLabel {
    final payStatus = (paymentStatus ?? '').toLowerCase().trim();

    if (status == 'cancelled') return 'Cancelled';
    if (status == 'delivered') return 'Delivered';
    if (status == 'completed') return 'Completed';
    if (status == 'on_delivery') return 'In Transit';
    if (status == 'done_preparing') return 'Ready';

    if (_isCod && (status == 'pending' || payStatus == 'cod_pending')) {
      return 'Awaiting Confirmation';
    }
    if (payStatus == 'pending_verification') return 'Under Review';
    if (status == 'accepted' || status == 'confirmed') return 'Processing';
    if (status == 'preparing' || payStatus == 'cod_approved') return 'Preparing';
    if (displayKey == 'processing') return 'Preparing';

    if (status == 'pending') {
      return paymentProofUrl != null ? 'Payment Review' : 'To Pay';
    }
    return status;
  }

  /// Pending GCash unpaid or COD awaiting confirmation can be cancelled.
  bool get canCancel {
    if (status != 'pending') return false;
    final payStatus = (paymentStatus ?? '').toLowerCase().trim();
    if (payStatus == 'pending_verification' || payStatus == 'verified') {
      return false;
    }
    return true;
  }
}

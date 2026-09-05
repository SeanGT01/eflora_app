import 'package:flutter/material.dart';
import '../utils/datetime_ph.dart';

/// Rider order model matching backend Order.to_dict() + enriched fields
class RiderOrder {
  final int id;
  final int customerId;
  final int storeId;
  final int? riderId;
  final String status;
  final double subtotalAmount;
  final double deliveryFee;
  final double? distanceKm;
  final double totalAmount;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final String? requestedDeliveryDate;
  final String? requestedDeliveryTime;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? storeAddress;
  final String? customerName;
  final String? customerContact;
  final String? customerTel;
  final String? customerPhone;
  final String? storeName;
  final String? riderName;
  final double? distanceFromStoreKm;
  final String? deliveryProofUrl;
  final String? deliveryProofPublicId;
  final String? deliveryProof2Url;
  final String? deliveryProof2PublicId;
  /// Photo uploaded by seller when marking order ready (packed / handoff verification).
  final String? donePreparingProofUrl;
  final List<RiderOrderItem> items;
  final DateTime? createdAt;

  const RiderOrder({
    required this.id,
    required this.customerId,
    required this.storeId,
    this.riderId,
    required this.status,
    required this.subtotalAmount,
    required this.deliveryFee,
    this.distanceKm,
    required this.totalAmount,
    this.paymentMethod,
    this.paymentStatus,
    this.deliveryAddress,
    this.deliveryNotes,
    this.requestedDeliveryDate,
    this.requestedDeliveryTime,
    this.customerLatitude,
    this.customerLongitude,
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress,
    this.customerName,
    this.customerContact,
    this.customerTel,
    this.customerPhone,
    this.storeName,
    this.riderName,
    this.distanceFromStoreKm,
    this.deliveryProofUrl,
    this.deliveryProofPublicId,
    this.deliveryProof2Url,
    this.deliveryProof2PublicId,
    this.donePreparingProofUrl,
    required this.items,
    this.createdAt,
  });

  factory RiderOrder.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? [])
        .map((i) => RiderOrderItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return RiderOrder(
      id: j['id'] ?? 0,
      customerId: j['customer_id'] ?? 0,
      storeId: j['store_id'] ?? 0,
      riderId: j['rider_id'],
      status: j['status'] ?? 'pending',
      subtotalAmount: _toDouble(j['subtotal_amount']),
      deliveryFee: _toDouble(j['delivery_fee']),
      distanceKm: j['distance_km']?.toDouble(),
      totalAmount: _toDouble(j['total_amount']),
      paymentMethod: j['payment_method'],
      paymentStatus: j['payment_status'],
      deliveryAddress: j['delivery_address'],
      deliveryNotes: j['delivery_notes'],
      requestedDeliveryDate: j['requested_delivery_date'],
      requestedDeliveryTime: j['requested_delivery_time'],
      customerLatitude: j['customer_latitude']?.toDouble(),
      customerLongitude: j['customer_longitude']?.toDouble(),
      storeLatitude: j['store_latitude']?.toDouble(),
      storeLongitude: j['store_longitude']?.toDouble(),
      storeAddress: j['store_address'],
      customerName: j['customer_name'],
      customerContact: j['customer_contact'],
      customerTel: j['customer_tel'],
      customerPhone: j['customer_phone']?.toString(),
      storeName: j['store_name'],
      riderName: j['rider_name'],
      distanceFromStoreKm: j['distance_from_store_km']?.toDouble(),
      deliveryProofUrl: j['delivery_proof_url'],
      deliveryProofPublicId: j['delivery_proof_public_id'],
      deliveryProof2Url: j['delivery_proof_2_url'],
      deliveryProof2PublicId: j['delivery_proof_2_public_id'],
      donePreparingProofUrl: j['done_preparing_proof_url'],
      items: items,
      createdAt: parseBackendDateTime(j['created_at']?.toString()),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.trim());
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  /// Text colour of the status pill, matching the web badge palette.
  Color get statusColor {
    switch (status) {
      case 'pending':         return const Color(0xFFA06030);
      case 'accepted':        return const Color(0xFF6A4A9A);
      case 'preparing':       return const Color(0xFF6A4A9A);
      case 'done_preparing':  return const Color(0xFF3F6B4E);
      case 'on_delivery':     return const Color(0xFFA04060);
      case 'delivered':       return const Color(0xFF3F6B4E);
      case 'completed':       return const Color(0xFFA04068);
      case 'cancelled':       return const Color(0xFF9B1C1C);
      default:                return const Color(0xFF9A8D85);
    }
  }

  /// Fill of the status pill.
  Color get statusBackgroundColor {
    switch (status) {
      case 'pending':         return const Color(0x73FFD2B4);
      case 'accepted':        return const Color(0x66D2BEF0);
      case 'preparing':       return const Color(0x66D2BEF0);
      case 'done_preparing':  return const Color(0x80C8E6D2);
      case 'on_delivery':     return const Color(0x66FFBED2);
      case 'delivered':       return const Color(0x80C8E6D2);
      case 'completed':       return const Color(0x2ED878A0);
      case 'cancelled':       return const Color(0x1FC24E68);
      default:                return const Color(0x8CFFFFFF);
    }
  }

  /// Hairline border of the status pill.
  Color get statusBorderColor {
    switch (status) {
      case 'pending':         return const Color(0x66E8A078);
      case 'accepted':        return const Color(0x59B070C8);
      case 'preparing':       return const Color(0x59B070C8);
      case 'done_preparing':  return const Color(0x597A9E7E);
      case 'on_delivery':     return const Color(0x4DC24E68);
      case 'delivered':       return const Color(0x597A9E7E);
      case 'completed':       return const Color(0x47C24E68);
      case 'cancelled':       return const Color(0x40C24E68);
      default:                return const Color(0xB3FFFFFF);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'accepted':        return 'Ready for Pickup';
      case 'done_preparing':  return 'Ready';
      case 'on_delivery':     return 'On Delivery';
      case 'delivered':       return 'Delivered';
      case 'completed':       return 'Completed';
      case 'cancelled':       return 'Cancelled';
      default:                return status;
    }
  }

  bool get isDeliveredOrCompleted =>
      status == 'delivered' || status == 'completed';

  bool get hasDeliveryProof =>
      (deliveryProofUrl != null && deliveryProofUrl!.isNotEmpty) ||
      (deliveryProof2Url != null && deliveryProof2Url!.isNotEmpty);
}

class RiderOrderItem {
      String get displayName => variantName != null && variantName!.isNotEmpty
          ? '$productName - $variantName'
          : productName;
  final int id;
  final int productId;
  final String productName;
  final String? variantName;
  final int quantity;
  final double price;
  final String? imageUrl;
  final List<Map<String, dynamic>> addons;
  final double addonsTotal;
  final double lineTotal;

  const RiderOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.addons = const [],
    this.addonsTotal = 0,
    this.lineTotal = 0,
  });

  factory RiderOrderItem.fromJson(Map<String, dynamic> j) {
    final addons = (j['addons'] as List? ?? [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final price = (j['price'] is int)
        ? (j['price'] as int).toDouble()
        : (j['price'] ?? 0.0).toDouble();
    final qty = j['quantity'] ?? 1;
    final addonsTotal = (j['addons_total'] as num?)?.toDouble() ??
        addons.fold<double>(0, (s, a) {
          final p = (a['price'] as num?)?.toDouble() ?? 0;
          final q = (a['quantity'] as num?)?.toInt() ?? 1;
          return s + ((a['total'] as num?)?.toDouble() ?? (p * q));
        });
    final computed = (price * qty) + addonsTotal;
    final apiLine = (j['total'] as num?)?.toDouble();
    final lineTotal = apiLine == null
        ? computed
        : (apiLine >= computed - 0.009 ? apiLine : computed);
    return RiderOrderItem(
      id: j['id'] ?? 0,
      productId: j['product_id'] ?? 0,
      productName: j['product_name'] ?? j['name'] ?? '',
      variantName: j['variant_name'],
      quantity: qty,
      price: price,
      imageUrl: j['product_image_url'] ?? j['image_url'],
      addons: addons,
      addonsTotal: addonsTotal,
      lineTotal: lineTotal,
    );
  }
}

class RiderProfile {
  final int id;
  final int userId;
  final int storeId;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? vehicleType;
  final String? licensePlate;
  final bool isActive;
  final String? storeName;
  final String? storeLogoUrl;

  const RiderProfile({
    required this.id,
    required this.userId,
    required this.storeId,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.vehicleType,
    this.licensePlate,
    this.isActive = true,
    this.storeName,
    this.storeLogoUrl,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> j) => RiderProfile(
   id: j['id'] ?? 0,
    userId: j['user_id'] ?? 0,
    storeId: j['store_id'] ?? 0,
    fullName: j['full_name'],
    email: j['email'],
    avatarUrl: j['avatar_url'],
    vehicleType: j['vehicle_type'],
    licensePlate: j['license_plate'],
    isActive: j['is_active'] ?? true,
    storeName: j['store_name'],
    storeLogoUrl: j['store_logo_url'],
  );
}

class RiderDashboard {
  final RiderProfile rider;
  final int todayOrders;
  final int todayDelivered;
  final RiderOrder? currentOrder;
  final List<RiderOrder> recentOrders;

  const RiderDashboard({
    required this.rider,
    required this.todayOrders,
    required this.todayDelivered,
    this.currentOrder,
    required this.recentOrders,
  });

  factory RiderDashboard.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] as Map<String, dynamic>? ?? {};
    final recent = (j['recent_orders'] as List? ?? [])
        .map((o) => RiderOrder.fromJson(o as Map<String, dynamic>))
        .toList();
    return RiderDashboard(
      rider: RiderProfile.fromJson(j['rider'] as Map<String, dynamic>? ?? {}),
      todayOrders: stats['today_orders'] ?? 0,
      todayDelivered: stats['today_delivered'] ?? 0,
      currentOrder: j['current_order'] != null
          ? RiderOrder.fromJson(j['current_order'] as Map<String, dynamic>)
          : null,
      recentOrders: recent,
    );
  }
}

class RiderStats {
  final int weeklyDeliveries;
  final int monthlyDeliveries;
  final int totalDeliveries;
  final double avgDeliveryTimeMinutes;

  const RiderStats({
    required this.weeklyDeliveries,
    required this.monthlyDeliveries,
    required this.totalDeliveries,
    required this.avgDeliveryTimeMinutes,
  });

  factory RiderStats.fromJson(Map<String, dynamic> j) {
    final s = j['stats'] as Map<String, dynamic>? ?? j;
    return RiderStats(
      weeklyDeliveries: s['weekly_deliveries'] ?? 0,
      monthlyDeliveries: s['monthly_deliveries'] ?? 0,
      totalDeliveries: s['total_deliveries'] ?? 0,
      avgDeliveryTimeMinutes: (s['avg_delivery_time_minutes'] ?? 0).toDouble(),
    );
  }
}

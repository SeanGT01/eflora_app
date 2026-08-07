
class DeliveryPreference {
  final DateTime? date;
  final String? timeSlot; // "08:00-12:00", "12:00-15:00", "15:00-18:00"

  const DeliveryPreference({this.date, this.timeSlot});

  Map<String, dynamic> toJson() => {
    'date': date?.toIso8601String(),
    'timeSlot': timeSlot,
  };

  factory DeliveryPreference.fromJson(Map<String, dynamic> json) {
    return DeliveryPreference(
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      timeSlot: json['timeSlot'] as String?,
    );
  }
}

class Address {
  final int? id;
  final String municipality;
  final String barangay;
  final String? street; // Optional
  final String? buildingDetails; // Optional (e.g., "Bldg 5, Unit 301, near Sari-Sari Store")
  final String addressLine; // Full formatted address
  final double latitude;
  final double longitude;
  final String? placeId; // Mapbox place_id
  final String addressLabel; // "Home", "Work", "Other"
  final bool isDefault;
  
  Address({
    this.id,
    required this.municipality,
    required this.barangay,
    this.street,
    this.buildingDetails,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.addressLabel = 'Home',
    this.isDefault = false,
  });
  
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      municipality: json['municipality'] ?? '',
      barangay: json['barangay'] ?? '',
      street: json['street'],
      buildingDetails: json['building_details'],
      addressLine: json['address_line'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      placeId: json['place_id'],
      addressLabel: json['address_label'] ?? 'Home',
      isDefault: json['is_default'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'municipality': municipality,
    'barangay': barangay,
    'street': street,
    'building_details': buildingDetails,
    'address_line': addressLine,
    'latitude': latitude,
    'longitude': longitude,
    'place_id': placeId,
    'address_label': addressLabel,
    'is_default': isDefault,
  };

  Address copyWith({
    int? id,
    String? municipality,
    String? barangay,
    String? street,
    String? buildingDetails,
    String? addressLine,
    double? latitude,
    double? longitude,
    String? placeId,
    String? addressLabel,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      street: street ?? this.street,
      buildingDetails: buildingDetails ?? this.buildingDetails,
      addressLine: addressLine ?? this.addressLine,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      addressLabel: addressLabel ?? this.addressLabel,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address && id != null && other.id == id;
  }

  @override
  int get hashCode => id ?? identityHashCode(this);
}

class StoreOrderTotal {
  final int storeId;
  final String storeName;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final double distanceKm;
  final bool canDeliver;
  final String? deliveryError;
  final List<String>? qrImages; // GCash QR codes per store
  final String? instructions; // GCash instructions
  final List<Map<String, dynamic>>? items; // Items in this store order

  StoreOrderTotal({
    required this.storeId,
    required this.storeName,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.distanceKm,
    required this.canDeliver,
    this.deliveryError,
    this.qrImages,
    this.instructions,
    this.items,
  });

  factory StoreOrderTotal.fromJson(Map<String, dynamic> json) {
    return StoreOrderTotal(
      storeId: json['store_id'] is String ? int.parse(json['store_id'] as String) : (json['store_id'] as int? ?? 0),
      storeName: json['store_name'] ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      canDeliver: json['can_deliver'] ?? false,
      deliveryError: json['delivery_error'],
      qrImages: List<String>.from(json['qr_images'] ?? []),
      instructions: json['instructions'],
      items: (json['items'] as List?)?.map((i) => i as Map<String, dynamic>).toList(),
    );
  }
}

class CheckoutValidationResponse {
  final bool success;
  final List<StoreOrderTotal> storeOrderTotals;
  final double grandTotal;
  final String? error;
  final List<String>? warnings; // Stores that can't deliver

  CheckoutValidationResponse({
    required this.success,
    required this.storeOrderTotals,
    required this.grandTotal,
    this.error,
    this.warnings,
  });

  factory CheckoutValidationResponse.fromJson(Map<String, dynamic> json) {
    final totals = (json['store_order_totals'] as List?)
        ?.map((t) => StoreOrderTotal.fromJson(t as Map<String, dynamic>))
        .toList() ?? [];
    
    return CheckoutValidationResponse(
      success: json['success'] ?? false,
      storeOrderTotals: totals,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      error: json['error'],
      warnings: List<String>.from(json['warnings'] ?? []),
    );
  }
}

class Order {
  final int id;
  final int customerId;
  final int storeId;
  final String status; // "pending", "confirmed", "shipped", etc.
  final String paymentStatus; // "pending_verification", "verified", "failed"
  final String paymentMethod; // "gcash"
  final double subtotalAmount;
  final double deliveryFee;
  final double totalAmount;
  final double distanceKm;
  final String deliveryAddress;
  final String? deliveryNotes;
  final DateTime requestedDeliveryDate;
  final String requestedDeliveryTime;
  final double customerLatitude;
  final double customerLongitude;
  final String? paymentProofUrl;
  final String? paymentProofPublicId;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotalAmount,
    required this.deliveryFee,
    required this.totalAmount,
    required this.distanceKm,
    required this.deliveryAddress,
    this.deliveryNotes,
    required this.requestedDeliveryDate,
    required this.requestedDeliveryTime,
    required this.customerLatitude,
    required this.customerLongitude,
    this.paymentProofUrl,
    this.paymentProofPublicId,
    required this.createdAt,
  });

  static int _toInt(dynamic v) => v is int ? v : int.parse(v.toString());

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: _toInt(json['id']),
      customerId: _toInt(json['customer_id']),
      storeId: _toInt(json['store_id']),
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'pending_verification',
      paymentMethod: json['payment_method'] ?? 'gcash',
      subtotalAmount: (json['subtotal_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryNotes: json['delivery_notes'],
      requestedDeliveryDate: DateTime.parse(json['requested_delivery_date'] ?? DateTime.now().toIso8601String()),
      requestedDeliveryTime: json['requested_delivery_time'] ?? '08:00-12:00',
      customerLatitude: (json['customer_latitude'] as num?)?.toDouble() ?? 0.0,
      customerLongitude: (json['customer_longitude'] as num?)?.toDouble() ?? 0.0,
      paymentProofUrl: json['payment_proof_url'],
      paymentProofPublicId: json['payment_proof_public_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CheckoutState {
  final Address? selectedAddress;
  final String? deliveryNotes;
  final DeliveryPreference deliveryPreference;
  final int currentStep; // 0: Address, 1: Review, 2: Payment
  final bool isProcessing;
  final String? error;
  final CheckoutValidationResponse? validationResponse;
  final List<Order>? createdOrders;

  const CheckoutState({
    this.selectedAddress,
    this.deliveryNotes,
    this.deliveryPreference = const DeliveryPreference(),
    this.currentStep = 0,
    this.isProcessing = false,
    this.error,
    this.validationResponse,
    this.createdOrders,
  });

  static const Object _unset = Object();

  CheckoutState copyWith({
    Address? selectedAddress,
    String? deliveryNotes,
    DeliveryPreference? deliveryPreference,
    int? currentStep,
    bool? isProcessing,
    Object? error = _unset,
    Object? validationResponse = _unset,
    Object? createdOrders = _unset,
  }) {
    return CheckoutState(
      selectedAddress: selectedAddress ?? this.selectedAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      deliveryPreference: deliveryPreference ?? this.deliveryPreference,
      currentStep: currentStep ?? this.currentStep,
      isProcessing: isProcessing ?? this.isProcessing,
      error: identical(error, _unset) ? this.error : error as String?,
      validationResponse: identical(validationResponse, _unset)
          ? this.validationResponse
          : validationResponse as CheckoutValidationResponse?,
      createdOrders: identical(createdOrders, _unset)
          ? this.createdOrders
          : createdOrders as List<Order>?,
    );
  }
}

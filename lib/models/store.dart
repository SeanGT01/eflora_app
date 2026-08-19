class Store {
  final int id;
  final String name;
  final String? description;
  final String? logoPath;
  final String status;
  // Detail fields
  final String? address;
  final String? municipality;
  final String? barangay;
  final String? street;
  final String? contactNumber;
  final String? formattedAddress;
  final String? logoUrl;
  final String? bannerUrl;
  final double? deliveryRadiusKm;
  final double? baseDeliveryFee;
  final double? latitude;
  final double? longitude;
  final int? productCount;
  final double? avgRating;
  final int? reviewCount;
  final Map<String, dynamic>? storeSchedule;
  final bool? canDeliverToCustomer;
  final String? deliveryReason;
  final String? deliveryMethod;
  final String? currentDeliveryGeojson;
  final List<String> selectedMunicipalities;
  final bool isCustomer;
  final StoreMapLocation? customerMapLocation;
  final List<StoreReview> reviews;

  const Store({
    required this.id,
    required this.name,
    this.description,
    this.logoPath,
    required this.status,
    this.address,
    this.municipality,
    this.barangay,
    this.street,
    this.contactNumber,
    this.formattedAddress,
    this.logoUrl,
    this.bannerUrl,
    this.deliveryRadiusKm,
    this.baseDeliveryFee,
    this.latitude,
    this.longitude,
    this.productCount,
    this.avgRating,
    this.reviewCount,
    this.storeSchedule,
    this.canDeliverToCustomer,
    this.deliveryReason,
    this.deliveryMethod,
    this.currentDeliveryGeojson,
    this.selectedMunicipalities = const [],
    this.isCustomer = false,
    this.customerMapLocation,
    this.reviews = const [],
  });

  factory Store.fromJson(Map<String, dynamic> j) {
    final customerRaw = j['customer_map_location'];
    return Store(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      description: j['description'],
      logoPath: j['logo_path'],
      status: j['status'] ?? 'active',
      address: j['address'],
      municipality: j['municipality'],
      barangay: j['barangay'],
      street: j['street'],
      contactNumber: j['contact_number'],
      formattedAddress: j['formatted_address'],
      logoUrl: j['logo_url'],
      bannerUrl: j['banner_url'],
      deliveryRadiusKm: (j['delivery_radius_km'] as num?)?.toDouble(),
      baseDeliveryFee: (j['base_delivery_fee'] as num?)?.toDouble(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      productCount: j['product_count'] as int?,
      avgRating: (j['avg_rating'] as num?)?.toDouble(),
      reviewCount: j['review_count'] as int?,
      storeSchedule: j['store_schedule'] as Map<String, dynamic>?,
      canDeliverToCustomer: j['can_deliver_to_customer'] as bool?,
      deliveryReason: j['delivery_reason'] as String?,
      deliveryMethod: j['delivery_method'],
      currentDeliveryGeojson: j['current_delivery_geojson'],
      selectedMunicipalities: (j['selected_municipalities'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      isCustomer: j['is_customer'] == true,
      customerMapLocation: customerRaw is Map
          ? StoreMapLocation.fromJson(Map<String, dynamic>.from(customerRaw))
          : null,
      reviews: (j['reviews'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((review) => StoreReview.fromJson(
                Map<String, dynamic>.from(review),
              ))
          .toList(),
    );
  }

  /// Best available logo URL (Cloudinary first, then legacy path)
  String? get effectiveLogoUrl => logoUrl ?? logoPath;
}

class StoreMapLocation {
  final double latitude;
  final double longitude;
  final String label;

  const StoreMapLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  factory StoreMapLocation.fromJson(Map<String, dynamic> json) =>
      StoreMapLocation(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        label: json['label']?.toString() ?? 'Default address',
      );
}

class StoreReview {
  final int rating;
  final String? comment;
  final String customerName;
  final DateTime? createdAt;

  const StoreReview({
    required this.rating,
    this.comment,
    required this.customerName,
    this.createdAt,
  });

  factory StoreReview.fromJson(Map<String, dynamic> json) => StoreReview(
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment']?.toString(),
        customerName: json['customer_name']?.toString() ?? 'Customer',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

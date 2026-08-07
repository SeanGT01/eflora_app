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
  });

  factory Store.fromJson(Map<String, dynamic> j) => Store(
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
  );

  /// Best available logo URL (Cloudinary first, then legacy path)
  String? get effectiveLogoUrl => logoUrl ?? logoPath;
}

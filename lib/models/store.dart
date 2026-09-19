import 'dart:convert';
import '../utils/datetime_ph.dart';

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
  final double? deliveryRatePerKm;
  final double? freeDeliveryMinimum;
  final bool freeDeliveryEnabled;
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
    this.deliveryRatePerKm,
    this.freeDeliveryMinimum,
    this.freeDeliveryEnabled = true,
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
      baseDeliveryFee: (j['base_delivery_fee'] as num?)?.toDouble() ??
          double.tryParse('${j['base_delivery_fee']}'),
      deliveryRatePerKm: (j['delivery_rate_per_km'] as num?)?.toDouble() ??
          double.tryParse('${j['delivery_rate_per_km']}'),
      freeDeliveryMinimum: (j['free_delivery_minimum'] as num?)?.toDouble() ??
          double.tryParse('${j['free_delivery_minimum']}'),
      freeDeliveryEnabled: j['free_delivery_enabled'] != false,
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
      selectedMunicipalities: () {
        final raw = j['selected_municipalities'];
        if (raw is List) {
          return raw
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        } else if (raw is String && raw.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              return decoded
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
            }
          } catch (_) {}
          return raw
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
        return const <String>[];
      }(),
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

  bool get usesRadiusDelivery =>
      deliveryMethod == 'radius' ||
      (deliveryMethod == null || deliveryMethod!.isEmpty);

  bool get usesMunicipalityDelivery => deliveryMethod == 'municipality';

  bool get usesCustomZoneDelivery => deliveryMethod == 'zone';

  /// Compact stat value for store details (e.g. "15km", "6", "Custom").
  String get deliveryCoverageStatValue {
    if (usesCustomZoneDelivery) return 'Custom';
    if (usesMunicipalityDelivery) {
      final n = selectedMunicipalities.length;
      return n > 0 ? '$n' : '—';
    }
    if (deliveryRadiusKm != null) {
      return '${deliveryRadiusKm!.toStringAsFixed(0)}km';
    }
    return '—';
  }

  String get deliveryCoverageStatLabel {
    if (usesMunicipalityDelivery) return 'Municipality/City coverage';
    return 'Delivery';
  }

  /// Human-readable coverage for info rows and map subtitle.
  String get deliveryCoverageSummary {
    if (usesCustomZoneDelivery) return 'Custom delivery zone';
    if (usesMunicipalityDelivery) {
      if (selectedMunicipalities.isNotEmpty) {
        return selectedMunicipalities.join(', ');
      }
      return 'Municipality/City coverage';
    }
    if (deliveryRadiusKm == null) return 'Store location and delivery coverage';
    return '${deliveryRadiusKm!.toStringAsFixed(0)} km delivery radius';
  }

  /// Short header chip, e.g. "15km delivery" / "6 Municipality/City coverage" / "Custom zone".
  String get deliveryCoverageChip {
    if (usesCustomZoneDelivery) return 'Custom zone';
    if (usesMunicipalityDelivery) {
      final n = selectedMunicipalities.length;
      return n > 0
          ? '$n Municipality/City coverage'
          : 'Municipality/City coverage';
    }
    if (deliveryRadiusKm == null) return 'Delivery area';
    return '${deliveryRadiusKm!.toStringAsFixed(0)}km delivery';
  }

  bool get hasFreeDelivery =>
      freeDeliveryEnabled &&
      freeDeliveryMinimum != null &&
      freeDeliveryMinimum! > 0;

  bool get isAlwaysFreeDelivery =>
      (baseDeliveryFee == null || baseDeliveryFee == 0) &&
      (deliveryRatePerKm == null || deliveryRatePerKm == 0);

  /// Human-readable delivery fee calculation summary.
  /// Examples:
  /// - "Free delivery for all orders"
  /// - "₱50.00 base + ₱20.00 / km"
  /// - "₱50.00 flat delivery fee"
  /// - "₱20.00 / km distance rate"
  String get deliveryFeeCalculationSummary {
    if (isAlwaysFreeDelivery) {
      return 'Free delivery for all orders';
    }
    final hasBase = baseDeliveryFee != null && baseDeliveryFee! > 0;
    final hasRate = deliveryRatePerKm != null && deliveryRatePerKm! > 0;

    if (hasBase && hasRate) {
      return '₱${baseDeliveryFee!.toStringAsFixed(2)} base + ₱${deliveryRatePerKm!.toStringAsFixed(2)} / km';
    } else if (hasBase) {
      return '₱${baseDeliveryFee!.toStringAsFixed(2)} flat delivery fee';
    } else if (hasRate) {
      return '₱${deliveryRatePerKm!.toStringAsFixed(2)} / km distance rate';
    }
    return 'Free delivery';
  }

  /// Explanation of how delivery fee is computed
  String get deliveryFeeExplanation {
    if (isAlwaysFreeDelivery) {
      return 'This store offers free delivery on all orders.';
    }
    final hasRate = deliveryRatePerKm != null && deliveryRatePerKm! > 0;
    if (hasRate) {
      return 'Calculated based on actual road distance from the store to your delivery address.';
    }
    return 'Flat delivery fee applies to all deliveries within the coverage area.';
  }
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
        createdAt: parseBackendDateTime(json['created_at']?.toString()),
      );
}

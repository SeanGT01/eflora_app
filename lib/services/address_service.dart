import 'package:dio/dio.dart';
import '../models/checkout.dart';
import '../models/api_result.dart';

class AddressService {
  final Dio _dio;
  // Use production Railway URL (same as main API)
  // The address endpoints are under /api (not /api/v1)
  static const String _baseUrl = 'https://eflora-system-production.up.railway.app/api';

  AddressService({required Dio dio}) : _dio = dio;

  /// Get all addresses for the logged-in user
  Future<ApiResult<List<Address>>> getAddresses() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/account/addresses',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final addresses = (response.data['addresses'] as List)
            .map((json) => Address.fromJson(json as Map<String, dynamic>))
            .toList();
        return ApiResult.success(addresses);
      } else {
        return ApiResult.error(
          'Failed to load addresses',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to load addresses',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Get a single address by ID
  Future<ApiResult<Address>> getAddress(int addressId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/account/addresses/$addressId',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final address = Address.fromJson(response.data['address'] as Map<String, dynamic>);
        return ApiResult.success(address);
      } else {
        return ApiResult.error(
          'Failed to load address',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to load address',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Add a new address
  Future<ApiResult<Address>> addAddress({
    required String municipality,
    required String barangay,
    required double latitude,
    required double longitude,
    String? street,
    String? buildingDetails,
    String addressLabel = 'Home',
    bool isDefault = false,
    String? placeId,
  }) async {
    try {
      final data = {
        'municipality': municipality,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
        'street': street,
        'building_details': buildingDetails,
        'address_label': addressLabel,
        'is_default': isDefault,
        'place_id': placeId,
      };

      final response = await _dio.post(
        '$_baseUrl/account/addresses',
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        final address = Address.fromJson(response.data['address'] as Map<String, dynamic>);
        return ApiResult.success(address);
      } else {
        return ApiResult.error(
          response.data['error'] ?? 'Failed to add address',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        _dioErrorMessage(e, 'Failed to add address'),
        e.response?.statusCode ?? 500,
      );
    }
  }

  String _dioErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      final message = (data['error'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    return e.message ?? fallback;
  }

  /// Update an existing address
  Future<ApiResult<Address>> updateAddress(
    int addressId, {
    required String municipality,
    required String barangay,
    required double latitude,
    required double longitude,
    String? street,
    String? buildingDetails,
    String addressLabel = 'Home',
    bool isDefault = false,
    String? placeId,
  }) async {
    try {
      final data = {
        'municipality': municipality,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
        'street': street,
        'building_details': buildingDetails,
        'address_label': addressLabel,
        'is_default': isDefault,
        'place_id': placeId,
      };

      final response = await _dio.put(
        '$_baseUrl/account/addresses/$addressId',
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final address = Address.fromJson(response.data['address'] as Map<String, dynamic>);
        return ApiResult.success(address);
      } else {
        return ApiResult.error(
          response.data['error'] ?? 'Failed to update address',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to update address',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Delete an address
  Future<ApiResult<void>> deleteAddress(int addressId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl/account/addresses/$addressId',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ApiResult.success(null);
      } else {
        return ApiResult.error(
          response.data['error'] ?? 'Failed to delete address',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to delete address',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Set an address as default
  Future<ApiResult<Address>> setDefaultAddress(int addressId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/account/addresses/$addressId/set-default',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final address = Address.fromJson(response.data['address'] as Map<String, dynamic>);
        return ApiResult.success(address);
      } else {
        return ApiResult.error(
          response.data['error'] ?? 'Failed to set default address',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to set default address',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Get municipalities in Laguna
  Future<ApiResult<List<String>>> getMunicipalities() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/laguna/municipalities',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final municipalities = List<String>.from(response.data['municipalities'] ?? []);
        return ApiResult.success(municipalities);
      } else {
        return ApiResult.error(
          'Failed to load municipalities',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to load municipalities',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Get barangays for a specific municipality
  Future<ApiResult<(List<String>, {double? lat, double? lng})>> getBarangays(String municipality) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/laguna/barangays/${Uri.encodeComponent(municipality)}',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final barangays = List<String>.from(response.data['barangays'] ?? []);
        final coords = response.data['coordinates'] as Map<String, dynamic>?;
        final lat = (coords?['lat'] as num?)?.toDouble();
        final lng = (coords?['lng'] as num?)?.toDouble();

        return ApiResult.success((
          barangays,
          lat: lat,
          lng: lng,
        ));
      } else {
        return ApiResult.error(
          'Failed to load barangays',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to load barangays',
        e.response?.statusCode ?? 500,
      );
    }
  }

  /// Reverse geocode coordinates using Mapbox (calls backend which uses Mapbox API)
  Future<ApiResult<Map<String, dynamic>>> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/seller/store/geocode',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ApiResult.success({
          'address': response.data['address'],
          'place_id': response.data['place_id'],
        });
      } else {
        return ApiResult.error(
          response.data['error'] ?? 'Failed to reverse geocode',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      return ApiResult.error(
        e.message ?? 'Failed to reverse geocode',
        e.response?.statusCode ?? 500,
      );
    }
  }
}

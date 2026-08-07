import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkout.dart';
import '../services/address_service.dart';

class AddressProvider extends ChangeNotifier {
  final AddressService _service;

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isLoading = false;
  String? _error;

  List<String> _municipalities = [];
  List<String> _barangays = [];
  double? _barangayLat;
  double? _barangayLng;

  bool _isMunicipalitiesLoading = false;
  bool _isBarangaysLoading = false;

  AddressProvider({required AddressService addressService}) : _service = addressService {
    loadAddresses();
    loadMunicipalities();
  }

  // Getters
  List<Address> get addresses => _addresses;
  Address? get selectedAddress => _selectedAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<String> get municipalities => _municipalities;
  List<String> get barangays => _barangays;
  double? get barangayLat => _barangayLat;
  double? get barangayLng => _barangayLng;
  bool get isMunicipalitiesLoading => _isMunicipalitiesLoading;
  bool get isBarangaysLoading => _isBarangaysLoading;

  /// Load all addresses from API
  Future<void> loadAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _service.getAddresses();
    result.when(
      success: (addresses) {
        _addresses = addresses;
        // Select default or first address
        _selectedAddress = addresses.isEmpty ? null : addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        _isLoading = false;
        _error = null;
      },
      error: (message, code) {
        _isLoading = false;
        _error = message;
      },
    );
    notifyListeners();
  }

  /// Select an address
  void selectAddress(Address address) {
    _selectedAddress = address;
    notifyListeners();
  }

  /// Add a new address
  Future<void> addAddress({
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
    final result = await _service.addAddress(
      municipality: municipality,
      barangay: barangay,
      latitude: latitude,
      longitude: longitude,
      street: street,
      buildingDetails: buildingDetails,
      addressLabel: addressLabel,
      isDefault: isDefault,
      placeId: placeId,
    );

    result.when(
      success: (address) {
        _error = null;
        notifyListeners();
        loadAddresses();
      },
      error: (message, code) {
        _error = message;
        notifyListeners();
      },
    );
  }

  /// Update an existing address
  Future<void> updateAddress(
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
    final result = await _service.updateAddress(
      addressId,
      municipality: municipality,
      barangay: barangay,
      latitude: latitude,
      longitude: longitude,
      street: street,
      buildingDetails: buildingDetails,
      addressLabel: addressLabel,
      isDefault: isDefault,
      placeId: placeId,
    );

    result.when(
      success: (address) {
        _error = null;
        notifyListeners();
        loadAddresses();
      },
      error: (message, code) {
        _error = message;
        notifyListeners();
      },
    );
  }

  /// Delete an address
  Future<void> deleteAddress(int addressId) async {
    final result = await _service.deleteAddress(addressId);
    result.when(
      success: (_) {
        if (_selectedAddress?.id == addressId) {
          _selectedAddress = null;
        }
        _error = null;
        notifyListeners();
        loadAddresses();
      },
      error: (message, code) {
        _error = message;
        notifyListeners();
      },
    );
  }

  /// Set an address as default
  Future<void> setDefaultAddress(int addressId) async {
    final result = await _service.setDefaultAddress(addressId);
    result.when(
      success: (_) {
        _error = null;
        notifyListeners();
        loadAddresses();
      },
      error: (message, code) {
        _error = message;
        notifyListeners();
      },
    );
  }

  /// Load municipalities
  Future<void> loadMunicipalities() async {
    _isMunicipalitiesLoading = true;
    notifyListeners();

    final result = await _service.getMunicipalities();
    result.when(
      success: (municipalities) {
        _municipalities = municipalities;
        _isMunicipalitiesLoading = false;
      },
      error: (message, code) {
        _isMunicipalitiesLoading = false;
        _error = message;
      },
    );
    notifyListeners();
  }

  /// Load barangays for a municipality
  Future<void> loadBarangays(String municipality) async {
    _isBarangaysLoading = true;
    notifyListeners();

    final result = await _service.getBarangays(municipality);
    result.when(
      success: (data) {
        _barangays = data.$1;
        _barangayLat = data.lat;
        _barangayLng = data.lng;
        _isBarangaysLoading = false;
      },
      error: (message, code) {
        _isBarangaysLoading = false;
        _error = message;
      },
    );
    notifyListeners();
  }
}

// ─ Setup function to configure Dio with JWT interceptor ─
Future<void> setupAddressServiceInterceptors() async {
  _dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add JWT token to Authorization header for all requests
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('🔑 Added JWT token to Address Service request');
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          print('❌ Address Service: 401 Unauthorized - JWT may be invalid or expired');
        }
        return handler.next(error);
      },
    ),
  );
}

// Singleton instances
final _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);

final _addressService = AddressService(dio: _dio);
final addressProvider = AddressProvider(addressService: _addressService);


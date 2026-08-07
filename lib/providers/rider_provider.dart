import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/rider.dart';
import '../services/rider_service.dart';

class RiderProvider extends ChangeNotifier {
  RiderDashboard? _dashboard;
  List<RiderOrder> _availableOrders = [];
  List<RiderOrder> _activeDeliveries = [];
  RiderStats? _stats;
  RiderProfile? _profile;
  bool _loading = false;
  String? _error;
  Position? _currentPosition;
  Timer? _locationTimer;
  int? _trackingOrderId;

  RiderDashboard? get dashboard => _dashboard;
  List<RiderOrder> get availableOrders => _availableOrders;
  List<RiderOrder> get activeDeliveries => _activeDeliveries;
  RiderStats? get stats => _stats;
  RiderProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _locationTimer != null;
  RiderOrder? get currentOrder => _dashboard?.currentOrder;

  // ── Dashboard ──────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await RiderService.getDashboard();
    _loading = false;

    if (result.isSuccess && result.data is Map) {
      _dashboard = RiderDashboard.fromJson(result.data as Map<String, dynamic>);
      _profile = _dashboard!.rider;
    } else {
      _error = result.errorMessage ?? 'Failed to load dashboard';
    }
    notifyListeners();
  }

  // ── Available Orders ───────────────────────────────────────────────
  Future<void> loadAvailableOrders() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await RiderService.getAvailableOrders();
    _loading = false;

    if (result.isSuccess && result.data is Map) {
      final data = result.data as Map<String, dynamic>;
      _availableOrders = (data['orders'] as List? ?? [])
          .map((o) => RiderOrder.fromJson(o as Map<String, dynamic>))
          .toList();
    } else {
      _error = result.errorMessage ?? 'Failed to load orders';
    }
    notifyListeners();
  }

  // ── Active Deliveries ──────────────────────────────────────────────
  Future<void> loadActiveDeliveries() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await RiderService.getAssignedOrders(status: 'on_delivery');
    _loading = false;

    if (result.isSuccess && result.data is Map) {
      final data = result.data as Map<String, dynamic>;
      _activeDeliveries = (data['orders'] as List? ?? [])
          .map((o) => RiderOrder.fromJson(o as Map<String, dynamic>))
          .toList();
    } else {
      _error = result.errorMessage ?? 'Failed to load deliveries';
    }
    notifyListeners();
  }

  // ── Accept Order ───────────────────────────────────────────────────
  Future<bool> acceptOrder(int orderId) async {
    final result = await RiderService.acceptOrder(orderId);
    if (result.isSuccess) {
      _availableOrders.removeWhere((o) => o.id == orderId);
      await loadActiveDeliveries();
      await loadDashboard();
      notifyListeners();
      return true;
    }
    _error = result.errorMessage ?? 'Failed to accept order';
    notifyListeners();
    return false;
  }

  // ── Update Order Status ────────────────────────────────────────────
  Future<bool> markDelivered(int orderId, {String? deliveryProofPath1, String? deliveryProofPath2}) async {
    // Both delivery proofs are required
    if ((deliveryProofPath1 == null || deliveryProofPath1.isEmpty) ||
        (deliveryProofPath2 == null || deliveryProofPath2.isEmpty)) {
      _error = 'Both delivery proof images are required';
      notifyListeners();
      return false;
    }

    // Upload first proof
    final uploadResult1 = await RiderService.uploadDeliveryProof(
      orderId: orderId,
      imagePath: deliveryProofPath1,
      proofIndex: 1,
    );
    
    if (!uploadResult1.isSuccess) {
      _error = uploadResult1.errorMessage ?? 'Failed to upload first proof';
      notifyListeners();
      return false;
    }

    // Upload second proof
    final uploadResult2 = await RiderService.uploadDeliveryProof(
      orderId: orderId,
      imagePath: deliveryProofPath2,
      proofIndex: 2,
    );
    
    if (!uploadResult2.isSuccess) {
      _error = uploadResult2.errorMessage ?? 'Failed to upload second proof';
      notifyListeners();
      return false;
    }

    // After both proofs are uploaded, mark as delivered
    final result = await RiderService.updateOrderStatus(orderId, 'delivered');
    if (result.isSuccess) {
      stopLocationTracking();
      _activeDeliveries.removeWhere((o) => o.id == orderId);
      await loadDashboard();
      notifyListeners();
      return true;
    }
    _error = result.errorMessage ?? 'Failed to update status';
    notifyListeners();
    return false;
  }

  // ── Stats ──────────────────────────────────────────────────────────
  Future<void> loadStats() async {
    final result = await RiderService.getStats();
    if (result.isSuccess && result.data is Map) {
      _stats = RiderStats.fromJson(result.data as Map<String, dynamic>);
      notifyListeners();
    }
  }

  // ── Profile ────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    final result = await RiderService.getProfile();
    if (result.isSuccess && result.data is Map) {
      final data = result.data as Map<String, dynamic>;
      _profile = RiderProfile.fromJson(data['profile'] as Map<String, dynamic>? ?? data);
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final result = await RiderService.updateProfile(data);
    if (result.isSuccess) {
      await loadProfile();
      return true;
    }
    return false;
  }

  // ── Location Tracking ──────────────────────────────────────────────
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    if (!await _checkLocationPermission()) return null;
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    notifyListeners();
    return _currentPosition;
  }

  void startLocationTracking(int orderId) {
    _trackingOrderId = orderId;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final pos = await getCurrentLocation();
      if (pos != null && _trackingOrderId != null) {
        await RiderService.postLocation(pos.latitude, pos.longitude, orderId: _trackingOrderId);
      }
    });
    // Send initial location immediately
    getCurrentLocation().then((pos) {
      if (pos != null && _trackingOrderId != null) {
        RiderService.postLocation(pos.latitude, pos.longitude, orderId: _trackingOrderId);
      }
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _trackingOrderId = null;
  }

  void clear() {
    stopLocationTracking();
    _dashboard = null;
    _availableOrders = [];
    _activeDeliveries = [];
    _stats = null;
    _profile = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationTracking();
    super.dispose();
  }
}

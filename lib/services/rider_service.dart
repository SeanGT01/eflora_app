import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'dart:io';

class RiderService {
  static const String _base = 'https://eflora-system-production.up.railway.app';
  static const String _api = '$_base/api/v1/rider';

  static Future<Map<String, String>> _authHeaders() async {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = await ApiService.getToken();
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  // ── Dashboard ──────────────────────────────────────────────────────
  static Future<ApiResult> getDashboard() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/dashboard'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Available Orders (accepted, no rider) ──────────────────────────
  static Future<ApiResult> getAvailableOrders() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/orders/available'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Assigned Orders ────────────────────────────────────────────────
  static Future<ApiResult> getAssignedOrders({String status = 'on_delivery'}) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/orders?status=$status'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Get Order Details ──────────────────────────────────────────────
  static Future<ApiResult> getOrderDetails(int orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/orders/$orderId'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Accept Order ───────────────────────────────────────────────────
  static Future<ApiResult> acceptOrder(int orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/orders/$orderId/accept'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Update Order Status ────────────────────────────────────────────
  static Future<ApiResult> updateOrderStatus(int orderId, String status) async {
    try {
      final res = await http.put(
        Uri.parse('$_api/orders/$orderId/update-status'),
        headers: await _authHeaders(),
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Post Location ──────────────────────────────────────────────────
  static Future<ApiResult> postLocation(double lat, double lng, {int? orderId}) async {
    try {
      final body = <String, dynamic>{'lat': lat, 'lng': lng};
      if (orderId != null) body['order_id'] = orderId;

      final res = await http.post(
        Uri.parse('$_api/location'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Upload Delivery Proof ──────────────────────────────────────────
  static Future<ApiResult> uploadDeliveryProof({
    required int orderId,
    required String imagePath,
    required int proofIndex,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return const ApiResult(
          statusCode: 400,
          error: 'File not found',
        );
      }

      // Get auth token
      final token = await ApiService.getToken();

      // Create multipart request
      final uploadUrl = '$_base/api/v1/rider/orders/$orderId/upload-delivery-proof';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['proof_index'] = proofIndex.toString()
        ..files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          return ApiResult(
            statusCode: 200,
            data: data,
          );
        }
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: response.body,
      );
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }


  // ── Rider Stats ────────────────────────────────────────────────────
  static Future<ApiResult> getStats() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/stats'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Profile ────────────────────────────────────────────────────────
  static Future<ApiResult> getProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/profile'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$_api/profile'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── OSRM Directions (route polyline) ─────────────────────────────
  static Future<List<List<double>>?> getRoute(
    double startLat, double startLng,
    double endLat, double endLng,
  ) async {
    final info = await getRouteInfo(startLat, startLng, endLat, endLng);
    return info?.points;
  }

  static Future<OsrmRouteInfo?> getRouteInfo(
    double startLat, double startLng,
    double endLat, double endLng,
  ) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '$startLng,$startLat;$endLng,$endLat'
          '?geometries=geojson&overview=full';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0] as Map<String, dynamic>;
          final coords = route['geometry']['coordinates'] as List;
          final points = coords
              .map<List<double>>((c) => [c[1].toDouble(), c[0].toDouble()])
              .toList();
          return OsrmRouteInfo(
            points: points,
            durationSec: (route['duration'] as num?)?.toDouble(),
            distanceM: (route['distance'] as num?)?.toDouble(),
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class OsrmRouteInfo {
  final List<List<double>> points;
  final double? durationSec;
  final double? distanceM;
  const OsrmRouteInfo({required this.points, this.durationSec, this.distanceM});
}

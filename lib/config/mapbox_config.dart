import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';

/// Mapbox **public** token (pk.*) — never embed in source; use dart-define or API.
class MapboxConfig {
  MapboxConfig._();

  static const String _envToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
  static String? _cached;

  /// Build-time override wins; otherwise fetch from backend once.
  static Future<String> publicToken({bool forceRefresh = false}) async {
    if (_envToken.isNotEmpty) return _envToken;
    if (!forceRefresh && _cached != null) return _cached!;
    try {
      final res = await http
          .get(Uri.parse('${ApiService.apiRoot}/customer/config/mapbox'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = (data['public_token'] as String?)?.trim() ?? '';
        _cached = token;
        return token;
      }
    } catch (_) {}
    return _cached ?? '';
  }
}

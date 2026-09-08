import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../services/api_service.dart';

/// Mapbox **public** token (pk.*) — never embed in source; use dart-define or API.
class MapboxConfig {
  MapboxConfig._();

  static const String _envToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
  static String? _cached;

  /// OpenStreetMap fallback URL template
  static const String osmFallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Cached or build-time public token (synchronous).
  static String get cachedToken => _cached ?? _envToken;

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

  /// Raster tiles for flutter_map (streets). OSM fallback if token missing.
  /// Uses standard 256px raster tiles to match flutter_map's default tileSize (256).
  static String rasterTileUrl(String token) {
    if (token.isEmpty) {
      return osmFallbackUrl;
    }
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$token';
  }

  /// Creates a NetworkTileProvider with retry support and deferred disposal
  /// to avoid connection resets when tiles are requested or disposed.
  static NetworkTileProvider createTileProvider() =>
      DeferredCloseNetworkTileProvider();
}

/// Closes the HTTP client after a short delay so in-flight tile requests
/// aren't aborted with noisy "Connection closed while receiving data" errors.
class DeferredCloseNetworkTileProvider extends NetworkTileProvider {
  DeferredCloseNetworkTileProvider()
      : super(httpClient: RetryClient(http.Client()));

  bool _disposeScheduled = false;

  @override
  void dispose() {
    if (_disposeScheduled) return;
    _disposeScheduled = true;
    final client = httpClient;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      try {
        client.close();
      } catch (_) {}
    });
  }
}

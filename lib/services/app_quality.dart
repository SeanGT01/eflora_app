import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Adaptive visual/network quality for weak devices (mirrors web `fx-lite`).
///
/// - **iOS / iPad:** rich (unless reduced motion)
/// - **Android:** rich only when RAM looks high (≥ ~6 GB); otherwise lite
/// - **Reduced motion:** disables decorative motion even on rich devices
class AppQuality {
  AppQuality._();
  static final AppQuality instance = AppQuality._();

  static const MethodChannel _channel = MethodChannel('eflora/device_info');

  bool _initialized = false;
  bool _isLite = false;
  bool _reduceMotion = false;
  int? _totalMemMb;
  int? _memoryClassMb;

  bool get isInitialized => _initialized;

  /// Low-end / constrained mode — drop blur, flowers, heavy hero motion.
  bool get isLite => _isLite;

  bool get isRich => !_isLite;

  bool get reduceMotion => _reduceMotion;

  bool get useBlur => !_isLite;

  bool get useFlowers => !_isLite && !_reduceMotion;

  bool get useRichHero => !_isLite && !_reduceMotion;

  bool get useHeavyShadows => !_isLite;

  /// Keep all shell tabs mounted (IndexedStack). Lite remounts the active tab only.
  bool get keepTabsAlive => !_isLite;

  bool get preloadImages => !_isLite;

  int get flowerCount => useFlowers ? 10 : 0;

  int get liteFlowerCount => 0;

  /// Unread badge poll while chat is closed.
  Duration get chatUnreadInterval =>
      _isLite ? const Duration(seconds: 20) : const Duration(seconds: 15);

  /// Faster poll while chat UI is open (inbox — not an open thread).
  Duration get chatLiveInterval =>
      _isLite ? const Duration(seconds: 15) : const Duration(seconds: 12);

  Duration get chatInboxSyncInterval =>
      _isLite ? const Duration(seconds: 20) : const Duration(seconds: 12);

  Duration get chatMessagePollInterval =>
      _isLite ? const Duration(seconds: 10) : const Duration(seconds: 7);

  int get imagePreloadLimit => _isLite ? 0 : 10;

  /// Call once before [runApp].
  Future<void> init() async {
    if (_initialized) return;

    _reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    if (kIsWeb) {
      _isLite = _reduceMotion;
      _initialized = true;
      return;
    }

    if (Platform.isIOS) {
      // Match web: iPhone/iPad keep rich FX unless reduced motion.
      _isLite = _reduceMotion;
      _initialized = true;
      debugPrint(
          'AppQuality: iOS → ${_isLite ? "lite" : "rich"} (reduceMotion=$_reduceMotion)');
      return;
    }

    if (Platform.isAndroid) {
      await _detectAndroid();
      if (_reduceMotion) _isLite = true;
      _initialized = true;
      debugPrint(
        'AppQuality: Android → ${_isLite ? "lite" : "rich"} '
        '(totalMemMb=$_totalMemMb memoryClassMb=$_memoryClassMb reduceMotion=$_reduceMotion)',
      );
      return;
    }

    // Desktop / other — keep rich for development.
    _isLite = _reduceMotion;
    _initialized = true;
  }

  Future<void> _detectAndroid() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getMemoryInfo');
      if (raw is Map) {
        final totalMem = _asInt(raw['totalMem']);
        final availMem = _asInt(raw['availMem']);
        final lowMemory = raw['lowMemory'] == true;
        final memoryClass = _asInt(raw['memoryClass']);
        final largeMemoryClass = _asInt(raw['largeMemoryClass']);

        if (totalMem != null) _totalMemMb = totalMem ~/ (1024 * 1024);
        _memoryClassMb = largeMemoryClass ?? memoryClass;

        // Web parity: rich when deviceMemory >= 6; lite for typical phones.
        final totalGb = _totalMemMb != null ? _totalMemMb! / 1024.0 : null;
        if (lowMemory) {
          _isLite = true;
        } else if (totalGb != null) {
          _isLite = totalGb < 5.5; // treat < ~6 GB as lite
        } else if (_memoryClassMb != null) {
          // memoryClass is heap hint (MB); ≤192 is usually low/mid devices
          _isLite = _memoryClassMb! <= 192;
        } else {
          // No signal — be conservative on Android (same as web without deviceMemory)
          _isLite = true;
        }

        // Very low free RAM → force lite even on high-total devices
        if (availMem != null && availMem < 400 * 1024 * 1024) {
          _isLite = true;
        }
        return;
      }
    } catch (e) {
      debugPrint('AppQuality: memory channel failed: $e');
    }
    // Conservative default for Android when detection fails
    _isLite = true;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  /// Test / debug override.
  void debugForceLite(bool lite) {
    _isLite = lite;
    _initialized = true;
  }
}

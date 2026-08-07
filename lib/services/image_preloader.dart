import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'app_quality.dart';

class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  final Set<String> _preloadedUrls = {};

  /// Preload a single image
  Future<void> preloadImage(String url) async {
    if (url.isEmpty || _preloadedUrls.contains(url)) return;
    
    try {
      // Use precacheImage with a temporary container
      final ImageProvider provider = CachedNetworkImageProvider(url);
      // Create a temporary context-less image cache
      await _preloadImageWithoutContext(provider);
      _preloadedUrls.add(url);
      debugPrint('✅ Preloaded image: $url');
    } catch (e) {
      debugPrint('❌ Failed to preload image: $url - $e');
    }
  }

  Future<void> _preloadImageWithoutContext(ImageProvider provider) async {
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    
    stream.addListener(
      ImageStreamListener(
        (_, __) => completer.complete(),
        onError: (dynamic error, stackTrace) => completer.completeError(error),
      ),
    );
    
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Image preload timeout'),
    );
  }

  /// Preload all product images
  Future<void> preloadProductImages(List<Product> products) async {
    final limit = AppQuality.instance.imagePreloadLimit;
    if (limit <= 0) return;

    final urls = products
        .map((p) => p.primaryImageUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // Load images with a small delay between each
    for (final url in urls.take(limit)) {
      await Future.delayed(const Duration(milliseconds: 100));
      await preloadImage(url);
    }
  }

  /// Clear preload cache
  void clearCache() {
    _preloadedUrls.clear();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
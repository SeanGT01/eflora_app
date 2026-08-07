import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String cloudName = 'dgyq49vi2'; // Your Cloudinary cloud name
  
  /// Get optimized Cloudinary URL with transformations
  static String getOptimizedUrl(String url, {
    int width = 300,
    int height = 300,
    String crop = 'fill',
    String quality = 'auto',
    String format = 'auto',
    bool faceDetection = false,
  }) {
    if (!url.contains('cloudinary.com')) {
      return url; // Not a Cloudinary URL
    }
    
    // Extract public ID from various URL formats
    String? publicId;
    
    // Try URI parsing
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      
      // Remove /image/upload or /image/upload/transformations
      String cleanPath = path.replaceFirst(RegExp(r'^/image/upload/'), '');
      
      // Remove existing transformations (everything before the version number or filename)
      // Transformations look like: c_fill,h_400,w_400/ or w_60,h_60,c_fill/
      // Version/blob looks like: v1773508390/ or f_auto/
      final parts = cleanPath.split('/');
      
      // Find where the public_id starts (after all transformations)
      int publicIdStartIdx = 0;
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        // Skip transformation parts (they contain commas or single letters followed by underscore)
        if (part.contains(',') || part.isEmpty || part.startsWith('v') && part.length > 1 && part[1].runes.first >= 48 && part[1].runes.first <= 57) {
          publicIdStartIdx = i + 1;
        } else if (!part.contains('_') && !part.contains('.')) {
          // Skip path components without extensions
          continue;
        } else {
          break;
        }
      }
      
      // Reconstruct public_id from remaining parts
      if (publicIdStartIdx < parts.length) {
        publicId = parts.sublist(publicIdStartIdx).join('/');
        // Remove file extension to get pure public_id
        if (publicId.contains('.')) {
          publicId = publicId.substring(0, publicId.lastIndexOf('.'));
        }
      }
    } catch (e) {
      debugPrint('⚠️ CloudinaryService: Error parsing URL: $url - $e');
    }
    
    // Fallback: if we couldn't extract publicId, try simple regex extraction
    if (publicId == null || publicId.isEmpty) {
      // Match pattern: /upload/.../ followed by version and path
      final match = RegExp(r'(?:image/upload/)?(?:[^/]+/)*([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*)(?:\.[a-z]+)?$').firstMatch(url);
      if (match != null) {
        publicId = match.group(1);
      }
    }
    
    // If still no publicId, try extracting e-flowers path
    if (publicId == null || publicId.isEmpty) {
      final eflowersMatch = RegExp(r'(?:e-flowers/[^/]+/[^/?]+)').firstMatch(url);
      if (eflowersMatch != null) {
        var extracted = eflowersMatch.group(0) ?? '';
        // Remove file extension
        if (extracted.contains('.')) {
          extracted = extracted.substring(0, extracted.lastIndexOf('.'));
        }
        publicId = extracted;
      }
    }
    
    // Build transformation string
    List<String> transformations = [];
    transformations.add('w_$width');
    transformations.add('h_$height');
    transformations.add('c_$crop');
    transformations.add('q_$quality');
    transformations.add('f_$format');
    if (faceDetection) {
      transformations.add('g_face');
    }
    
    final transformString = transformations.join(',');
    
    // If we could extract public_id, build clean URL
    if (publicId != null && publicId.isNotEmpty) {
      return 'https://res.cloudinary.com/$cloudName/image/upload/$transformString/$publicId';
    }
    
    // Fallback: try the original approach
    String cleanUrl = url;
    if (url.contains('/v1/_e-flowers/')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path;
        final parts = path.split('/_e-flowers/');
        if (parts.length > 1) {
          final pubId = 'e-flowers/${parts[1].split('.').first}';
          cleanUrl = 'https://res.cloudinary.com/$cloudName/image/upload/$pubId';
        }
      }
    }
    
    // Last resort: insert transformations into original URL
    return cleanUrl.replaceFirst('/upload/', '/upload/$transformString/');
  }
  
  /// Get thumbnail URL (small size for lists)
  static String getThumbnailUrl(String url, {int size = 150}) {
    return getOptimizedUrl(url, width: size, height: size);
  }
  
  /// Get medium size URL (for product details)
  static String getMediumUrl(String url, {int size = 400}) {
    return getOptimizedUrl(url, width: size, height: size);
  }
  
  /// Get large size URL (for fullscreen view)
  static String getLargeUrl(String url, {int size = 800}) {
    return getOptimizedUrl(url, width: size, height: size);
  }
  
  /// Get avatar URL with face detection
  static String getAvatarUrl(String url, {int size = 300}) {
    return getOptimizedUrl(url, width: size, height: size, faceDetection: true);
  }
  
  /// Get blur-up placeholder (tiny blurry image while loading)
  static String getPlaceholderUrl(String url, {int size = 20}) {
    return getOptimizedUrl(url, width: size, height: size, quality: '20');
  }
  
  /// Check if URL is from Cloudinary
  static bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com');
  }
  
  /// Fix malformed Cloudinary URL
  static String? fixMalformedUrl(String url) {
    if (!url.contains('cloudinary.com')) return url;
    
    // Fix /v1/_e-flowers/ pattern
    if (url.contains('/v1/_e-flowers/')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path;
        final parts = path.split('/_e-flowers/');
        if (parts.length > 1) {
          final publicId = 'e-flowers/${parts[1].split('.').first}';
          return 'https://res.cloudinary.com/$cloudName/image/upload/$publicId';
        }
      }
    }
    
    return url;
  }
}
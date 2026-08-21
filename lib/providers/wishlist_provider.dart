import 'package:flutter/foundation.dart';
import '../models/wishlist.dart';
import '../services/api_service.dart';

class WishlistProvider extends ChangeNotifier {
  List<WishlistItem> _items = [];
  bool _loading = false;
  /// productId -> set of variant keys: null means main product
  final Map<int, Set<int?>> _productKeys = {};

  List<WishlistItem> get items => _items;
  bool get loading => _loading;
  int get count => _items.length;

  bool isWished(int productId, {int? variantId}) {
    final keys = _productKeys[productId];
    if (keys == null) return false;
    return keys.contains(variantId);
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    final result = await ApiService.getWishlist();
    if (showLoading) _loading = false;

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      final list = (d['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => WishlistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _items = list;
      _rebuildKeysFromItems();
    }
    notifyListeners();
  }

  void _rebuildKeysFromItems() {
    _productKeys.clear();
    for (final item in _items) {
      _productKeys.putIfAbsent(item.productId, () => <int?>{}).add(item.variantId);
    }
  }

  Future<void> loadForProduct(int productId) async {
    final result = await ApiService.getWishlistForProduct(productId);
    if (!result.isSuccess || result.data is! Map) return;
    final d = result.data as Map<String, dynamic>;
    final raw = d['variant_ids'] as List? ?? [];
    final keys = <int?>{};
    for (final v in raw) {
      if (v == null) {
        keys.add(null);
      } else if (v is int) {
        keys.add(v);
      } else if (v is num) {
        keys.add(v.toInt());
      }
    }
    _productKeys[productId] = keys;
    notifyListeners();
  }

  Future<String?> toggle(int productId, {int? variantId}) async {
    final result = await ApiService.toggleWishlist(productId, variantId: variantId);
    if (!result.isSuccess || result.data is! Map) {
      return result.error ?? 'Could not update wishlist';
    }
    final d = result.data as Map<String, dynamic>;
    final wished = d['wished'] == true;
    final keys = _productKeys.putIfAbsent(productId, () => <int?>{});
    if (wished) {
      keys.add(variantId);
      if (d['item'] is Map) {
        final item = WishlistItem.fromJson(Map<String, dynamic>.from(d['item'] as Map));
        _items.removeWhere((e) => e.productId == productId && e.variantId == variantId);
        _items.insert(0, item);
      }
    } else {
      keys.remove(variantId);
      _items.removeWhere((e) => e.productId == productId && e.variantId == variantId);
    }
    notifyListeners();
    return null;
  }

  Future<String?> removeItem(int itemId) async {
    final result = await ApiService.removeWishlistItem(itemId);
    if (!result.isSuccess) {
      return result.error ?? 'Could not remove item';
    }
    WishlistItem? removed;
    for (final e in _items) {
      if (e.id == itemId) {
        removed = e;
        break;
      }
    }
    _items.removeWhere((e) => e.id == itemId);
    if (removed != null) {
      _productKeys[removed.productId]?.remove(removed.variantId);
    }
    notifyListeners();
    return null;
  }

  void reset() {
    _items = [];
    _productKeys.clear();
    _loading = false;
    notifyListeners();
  }
}

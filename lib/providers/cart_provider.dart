import 'dart:async';

import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  Cart? _cart;
  bool _loading = false;
  final Map<int, Timer> _qtyDebounce = {};
  final Map<int, int> _pendingQty = {};

  Cart? get cart => _cart;
  bool get loading => _loading;
  int get itemCount => _cart?.itemCount ?? 0;
  double get total => _cart?.total ?? 0;
  List<CartItem> get items => _cart?.items ?? [];

  // Selection-aware getters
  List<CartItem> get selectedItems => _cart?.selectedItems ?? [];
  double get selectedTotal => _cart?.selectedTotal ?? 0;
  int get selectedItemCount => _cart?.selectedItemCount ?? 0;
  Map<int, StoreCartGroup> get storeGroups => _cart?.storeGroups ?? {};
  bool get hasSelection => selectedItems.isNotEmpty;

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }

    final result = await ApiService.getCart();
    if (showLoading) _loading = false;

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      _cart = Cart.fromJson(d);
      debugPrint('✅ Cart loaded with ${_cart?.items.length} items');

      // Log variants if any
      for (var item in _cart?.items ?? []) {
        if (item.isVariant) {
          debugPrint('   📦 Variant item: ${item.name} (ID: ${item.variantId})');
        }
      }
    } else {
      final msg = result.errorMessage ?? '';
      // Expected for rider/seller sessions — don't treat as a hard failure.
      if (msg.toLowerCase().contains('customer access')) {
        _cart = null;
      } else {
        debugPrint('❌ Failed to load cart: $msg');
      }
    }

    notifyListeners();
  }

  /// Toggle selection of a single cart item
  Future<void> toggleItemSelection(int itemId) async {
    // Optimistic update
    if (_cart != null) {
      final idx = _cart!.items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        _cart!.items[idx].isSelected = !_cart!.items[idx].isSelected;
        notifyListeners();
      }
    }

    final result = await ApiService.toggleCartItemSelection(itemId);
    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      // Ensure we extract the 'cart' object from the response
      final cartData =
          d.containsKey('cart') ? d['cart'] as Map<String, dynamic> : d;
      _cart = Cart.fromJson(cartData);
      debugPrint(
          '✅ Cart toggled: ${_cart?.items.length} items, stores: ${storeGroups.length}');
      notifyListeners();
    }
  }

  /// Toggle selection of all items from a specific store
  Future<void> toggleStoreSelection(int storeId) async {
    if (_cart == null) return;

    // Determine target state: if all selected, deselect all; otherwise select all
    final group = storeGroups[storeId];
    if (group == null) return;
    final targetSelected = !group.allSelected;

    // Optimistic update
    for (final item in _cart!.items) {
      if (item.storeId == storeId) {
        item.isSelected = targetSelected;
      }
    }
    notifyListeners();

    final result =
        await ApiService.toggleStoreSelection(storeId, targetSelected);
    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      // Ensure we extract the 'cart' object from the response
      final cartData =
          d.containsKey('cart') ? d['cart'] as Map<String, dynamic> : d;
      _cart = Cart.fromJson(cartData);
      debugPrint('✅ Store $storeId toggled: ${_cart?.items.length} items');
      notifyListeners();
    }
  }

  Future<String?> addItem(
    int productId, {
    int qty = 1,
    int? variantId,
    List<int>? addonOptionIds,
  }) async {
    // ✅ Use unified addToCart - handles both main products and variants
    final result =
        await ApiService.addToCart(
          productId,
          qty,
          variantId: variantId,
          addonOptionIds: addonOptionIds,
        );

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      _cart = Cart.fromJson(d);
      notifyListeners();

      // Find the added item for logging - FIXED THE NULL SAFETY ISSUE
      if (_cart != null && _cart!.items.isNotEmpty) {
        try {
          final addedItem = _cart!.items.firstWhere(
            (item) => item.productId == productId && item.variantId == variantId,
          );
          debugPrint(
              '✅ Added to cart: ${addedItem.name} x$qty (Variant: ${variantId != null ? 'Yes' : 'No'})');
        } catch (e) {
          // Item not found with exact match, try finding by productId only
          try {
            final addedItem = _cart!.items.firstWhere(
              (item) => item.productId == productId,
            );
            debugPrint('✅ Added to cart: ${addedItem.name} x$qty');
          } catch (e) {
            debugPrint('✅ Added to cart (item found in cart)');
          }
        }
      }
      return null;
    }

    return result.errorMessage ?? 'Failed to add item';
  }

  Future<void> updateItem(int itemId, int qty) async {
    if (_cart == null) return;
    final idx = _cart!.items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = _cart!.items[idx];
    if (qty <= 0) {
      await removeItem(itemId);
      return;
    }
    if (qty > item.stockQuantity) return;
    if (item.quantity == qty) return;

    // Instant local update — debounce the network write
    item.quantity = qty;
    notifyListeners();

    _pendingQty[itemId] = qty;
    _qtyDebounce[itemId]?.cancel();
    _qtyDebounce[itemId] = Timer(const Duration(milliseconds: 400), () {
      _flushQtyUpdate(itemId);
    });
  }

  Future<void> _flushQtyUpdate(int itemId) async {
    final qty = _pendingQty.remove(itemId);
    _qtyDebounce.remove(itemId);
    if (qty == null) return;

    final result = await ApiService.updateCartItem(itemId, qty);

    // Newer local edits are still pending — skip applying this response
    if (_pendingQty.containsKey(itemId) || _qtyDebounce.containsKey(itemId)) {
      return;
    }

    if (!result.isSuccess) {
      debugPrint('❌ Qty sync failed for item $itemId: ${result.errorMessage}');
      await load(showLoading: false);
    }
  }

  Future<void> removeItem(int itemId) async {
    _qtyDebounce[itemId]?.cancel();
    _qtyDebounce.remove(itemId);
    _pendingQty.remove(itemId);

    // Optimistic remove
    if (_cart != null) {
      _cart!.items.removeWhere((i) => i.id == itemId);
      notifyListeners();
    }

    final result = await ApiService.removeFromCart(itemId);
    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      _cart = Cart.fromJson(d);
      notifyListeners();
    } else if (!result.isSuccess) {
      await load(showLoading: false);
    }
  }

  /// Remove one add-on from a cart line (matches web removeCartAddon).
  Future<void> removeAddon(int itemId, int addonOptionId) async {
    if (_cart == null) return;
    final idx = _cart!.items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = _cart!.items[idx];
    final newAddons =
        item.addons.where((a) => a.addonOptionId != addonOptionId).toList();
    if (newAddons.length == item.addons.length) return;

    final newAddonsTotal =
        newAddons.fold<double>(0, (s, a) => s + a.price * a.quantity);
    _cart!.items[idx] = item.copyWith(
      addons: newAddons,
      addonsTotal: newAddonsTotal,
    );
    notifyListeners();

    final result = await ApiService.removeCartAddon(itemId, addonOptionId);
    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      _cart = Cart.fromJson(d);
      notifyListeners();
    } else if (!result.isSuccess) {
      await load(showLoading: false);
    }
  }

  Future<void> clear() async {
    for (final t in _qtyDebounce.values) {
      t.cancel();
    }
    _qtyDebounce.clear();
    _pendingQty.clear();
    await ApiService.clearCart();
    _cart = null;
    notifyListeners();
  }

  void reset() {
    for (final t in _qtyDebounce.values) {
      t.cancel();
    }
    _qtyDebounce.clear();
    _pendingQty.clear();
    _cart = null;
    notifyListeners();
  }
}

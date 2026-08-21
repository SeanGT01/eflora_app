import 'package:flutter/material.dart';
import '../models/checkout.dart';
import '../services/checkout_service.dart';
import '../services/api_service.dart';

class CheckoutProvider extends ChangeNotifier {
  CheckoutState _state = const CheckoutState();

  // Buy Now mode fields
  bool _buyNowMode = false;
  int? _buyNowProductId;
  int? _buyNowVariantId;
  int _buyNowQuantity = 1;
  List<int> _buyNowAddonOptionIds = const [];

  bool get buyNowMode => _buyNowMode;
  int? get buyNowProductId => _buyNowProductId;
  int? get buyNowVariantId => _buyNowVariantId;
  int get buyNowQuantity => _buyNowQuantity;
  List<int> get buyNowAddonOptionIds => _buyNowAddonOptionIds;

  CheckoutState get state => _state;
  Address? get selectedAddress => _state.selectedAddress;
  String? get deliveryNotes => _state.deliveryNotes;
  DeliveryPreference get deliveryPreference => _state.deliveryPreference;
  int get currentStep => _state.currentStep;
  bool get isProcessing => _state.isProcessing;
  String? get error => _state.error;
  CheckoutValidationResponse? get validationResponse => _state.validationResponse;
  List<Order>? get createdOrders => _state.createdOrders;

  bool canProceedToStep1() {
    return _state.selectedAddress != null;
  }

  bool canProceedToStep2() {
    return canProceedToStep1() && _state.validationResponse?.success == true;
  }

  void setSelectedAddress(Address address) {
    // Changing address invalidates prior delivery checks / error banners.
    _state = _state.copyWith(
      selectedAddress: address,
      error: null,
      validationResponse: null,
    );
    notifyListeners();
  }

  void initializeSelectedAddress(Address? address) {
    if (address == null || _state.selectedAddress != null) return;
    _state = _state.copyWith(
      selectedAddress: address,
      error: null,
    );
    notifyListeners();
  }

  void setDeliveryNotes(String notes) {
    _state = _state.copyWith(deliveryNotes: notes);
    notifyListeners();
  }

  void setDeliveryPreference(DateTime date, String timeSlot) {
    final preference = DeliveryPreference(date: date, timeSlot: timeSlot);
    _state = _state.copyWith(deliveryPreference: preference);
    notifyListeners();
  }

  void setBuyNowItem({
    required int productId,
    int? variantId,
    required int quantity,
    List<int>? addonOptionIds,
  }) {
    _buyNowMode = true;
    _buyNowProductId = productId;
    _buyNowVariantId = variantId;
    _buyNowQuantity = quantity;
    _buyNowAddonOptionIds = List<int>.from(addonOptionIds ?? const []);
  }

  void nextStep() {
    if (_state.currentStep < 2) {
      _state = _state.copyWith(currentStep: _state.currentStep + 1);
      notifyListeners();
    }
  }

  void previousStep() {
    if (_state.currentStep > 0) {
      _state = _state.copyWith(currentStep: _state.currentStep - 1);
      notifyListeners();
    }
  }

  Future<bool> validateCheckout({List<Map<String, dynamic>>? items}) async {
    if (!canProceedToStep1()) {
      _state = _state.copyWith(
        error: 'Please select a delivery address',
      );
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isProcessing: true, error: null);
    notifyListeners();

    try {
      ApiResult response;

      if (_buyNowMode && _buyNowProductId != null) {
        // Buy Now mode: validate with product data directly
        response = await CheckoutService.buyNowValidate(
          productId: _buyNowProductId!,
          variantId: _buyNowVariantId,
          quantity: _buyNowQuantity,
          addressId: _state.selectedAddress!.id ?? 0,
          addonOptionIds: _buyNowAddonOptionIds,
        );
      } else {
        // Normal cart checkout
        response = await CheckoutService.validateCheckout(
          addressId: _state.selectedAddress!.id ?? 0,
          deliveryNotes: _state.deliveryNotes ?? '',
          items: items,
        );
      }

      if (response.isSuccess) {
        final validation = response.data as CheckoutValidationResponse;
        
        if (!validation.success) {
          _state = _state.copyWith(
            isProcessing: false,
            error: validation.error ?? 'Checkout validation failed',
            validationResponse: validation,
          );
          notifyListeners();
          return false;
        }

        // Check for delivery warnings (stores that can't deliver)
        if (validation.warnings != null && validation.warnings!.isNotEmpty) {
          debugPrint('⚠️ Delivery warnings: ${validation.warnings}');
        }

        _state = _state.copyWith(
          isProcessing: false,
          validationResponse: validation,
          error: null,
        );
        notifyListeners();
        return true;
      } else {
        final failedValidation = response.data is CheckoutValidationResponse
            ? response.data as CheckoutValidationResponse
            : null;
        _state = _state.copyWith(
          isProcessing: false,
          error: response.errorMessage ??
              failedValidation?.error ??
              'Validation failed',
          validationResponse: failedValidation,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> createOrders({
    String? paymentProofUrl,
    String? paymentProofPublicId,
    Map<int, Map<String, String>>? storePaymentProofs,
    Map<int, DateTime>? storeDeliveryDates,
    Map<int, String>? storeDeliveryTimes,
    Map<int, String>? storePaymentMethods,
  }) async {
    if (!canProceedToStep2()) {
      _state = _state.copyWith(error: 'Please complete previous steps');
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isProcessing: true, error: null);
    notifyListeners();

    try {
      ApiResult response;

      if (_buyNowMode && _buyNowProductId != null) {
        // Buy Now mode: create order directly from product
        final firstProof = (storePaymentProofs != null && storePaymentProofs.isNotEmpty)
            ? storePaymentProofs.values.first
            : null;
        final firstMethod = (storePaymentMethods != null && storePaymentMethods.isNotEmpty)
            ? storePaymentMethods.values.first
            : 'gcash';
        response = await CheckoutService.buyNowCreateOrder(
          productId: _buyNowProductId!,
          variantId: _buyNowVariantId,
          quantity: _buyNowQuantity,
          addressId: _state.selectedAddress!.id ?? 0,
          deliveryNotes: _state.deliveryNotes ?? '',
          deliveryDate: storeDeliveryDates!.values.first,
          deliveryTime: storeDeliveryTimes!.values.first,
          paymentProofUrl: paymentProofUrl ?? firstProof?['url'],
          paymentProofPublicId: paymentProofPublicId ?? firstProof?['public_id'],
          paymentMethod: firstMethod,
          addonOptionIds: _buyNowAddonOptionIds,
        );
      } else {
        // Normal cart checkout with per-store payment proofs
        // Build validated orders data from validation response with actual items
        final validatedOrders = _state.validationResponse?.storeOrderTotals.map((st) => {
          'store_id': st.storeId,
          'subtotal': st.subtotal,
          'delivery_fee': st.deliveryFee,
          'distance_km': st.distanceKm,
          'total': st.total,
          'items': st.items ?? [], // Use actual items from validation response
        }).toList();

        response = await CheckoutService.createOrders(
          addressId: _state.selectedAddress!.id ?? 0,
          deliveryNotes: _state.deliveryNotes ?? '',
          paymentProofUrl: paymentProofUrl,
          paymentProofPublicId: paymentProofPublicId,
          storePaymentProofs: storePaymentProofs,
          validatedOrders: validatedOrders,
          storeDeliveryDates: storeDeliveryDates,
          storeDeliveryTimes: storeDeliveryTimes,
          storePaymentMethods: storePaymentMethods,
        );
      }

      if (response.isSuccess && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final orders = data['orders'] as List<Order>? ?? [];

        _state = _state.copyWith(
          isProcessing: false,
          createdOrders: orders,
          currentStep: 3, // Success step
          error: null,
        );
        notifyListeners();
        return true;
      } else {
        _state = _state.copyWith(
          isProcessing: false,
          error: response.errorMessage ?? 'Failed to create orders',
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _state = const CheckoutState();
    _buyNowMode = false;
    _buyNowProductId = null;
    _buyNowVariantId = null;
    _buyNowQuantity = 1;
    _buyNowAddonOptionIds = const [];
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}

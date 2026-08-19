import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/checkout.dart';
import 'api_service.dart';
import 'dart:developer' as developer;

class CheckoutService {
  static const String _baseUrl = 'https://eflora-system-production.up.railway.app/api/v1/checkout';

  /// Extract GCash QR image URLs from API `gcash_qr_codes` (primary first).
  /// Backend [GCashQR.to_dict] uses `url`, not `qr_image_url`.
  static List<String> extractQrImageUrls(dynamic rawCodes) {
    if (rawCodes is! List || rawCodes.isEmpty) return const [];

    final entries = <Map<String, dynamic>>[];
    for (final item in rawCodes) {
      if (item is Map) {
        entries.add(Map<String, dynamic>.from(item));
      } else if (item is String && item.trim().isNotEmpty) {
        entries.add({'url': item.trim()});
      }
    }
    if (entries.isEmpty) return const [];

    entries.sort((a, b) {
      final aPrimary = a['is_primary'] == true ? 0 : 1;
      final bPrimary = b['is_primary'] == true ? 0 : 1;
      if (aPrimary != bPrimary) return aPrimary - bPrimary;
      final aOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
      final bOrder = (b['sort_order'] as num?)?.toInt() ?? 0;
      return aOrder - bOrder;
    });

    return entries
        .map((qr) {
          final url = (qr['url'] ??
                  qr['cloudinary_url'] ??
                  qr['qr_image_url'] ??
                  '')
              .toString()
              .trim();
          return url;
        })
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static StoreOrderTotal storeTotalFromOrder(Map<String, dynamic> order) {
    final rawSid = order['store_id'];
    final parsedSid = rawSid is int ? rawSid : int.parse(rawSid.toString());
    return StoreOrderTotal(
      storeId: parsedSid,
      storeName: order['store_name'] ?? 'Unknown Store',
      subtotal: (order['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (order['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      total: (order['total'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (order['distance_km'] as num?)?.toDouble() ?? 0.0,
      canDeliver: true,
      qrImages: extractQrImageUrls(order['gcash_qr_codes']),
      instructions: order['gcash_instructions'] as String?,
      items: (order['items'] as List?)
          ?.map((i) => i as Map<String, dynamic>)
          .toList(),
      allowCod: order['allow_cod'] == true,
      freeDeliveryEnabled: order['free_delivery_enabled'] == true,
      freeDeliveryMinimum: (order['free_delivery_minimum'] as num?)?.toDouble(),
      freeDeliveryApplied: order['free_delivery_applied'] == true,
      amountToFreeDelivery: (order['amount_to_free_delivery'] as num?)?.toDouble(),
    );
  }

  /// Validate checkout - sends cart delivery address to backend
  /// Backend will validate delivery, calculate fees, return store totals and QR codes
  static Future<ApiResult> validateCheckout({
    required int addressId,
    required String deliveryNotes,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final payload = {
        'delivery_address_id': addressId,
        'delivery_notes': deliveryNotes,
        if (items != null && items.isNotEmpty) 'items': items,
      };

      developer.log('Validating checkout: $payload');
      
      final token = await ApiService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/validate'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      developer.log('Validate checkout response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Transform backend response to CheckoutValidationResponse format
        // Backend returns: {success: true, orders: [...], address: {...}}
        // Or on error: {success: false, error: "", undeliverable_stores: [...]}
        
        if (data['success'] != true) {
          final warnings = <String>[];
          final undeliverable = data['undeliverable_stores'] as List? ?? [];
          for (final store in undeliverable) {
            warnings.add('${store['store_name']}: ${store['reason']}');
          }
          
          return ApiResult(
            statusCode: 400,
            error: data['error'] ?? 'Validation failed',
            data: CheckoutValidationResponse(
              success: false,
              storeOrderTotals: [],
              grandTotal: 0,
              error: data['error'],
              warnings: warnings,
            ),
          );
        }

        // Build store order totals from orders
        final orders = data['orders'] as List? ?? [];
        final storeOrderTotals = <StoreOrderTotal>[];
        double grandTotal = 0;

        for (final order in orders) {
          final storeTotal = storeTotalFromOrder(Map<String, dynamic>.from(order as Map));
          
          storeOrderTotals.add(storeTotal);
          grandTotal += storeTotal.total;
        }

        return ApiResult(
          statusCode: 200,
          data: CheckoutValidationResponse(
            success: true,
            storeOrderTotals: storeOrderTotals,
            grandTotal: grandTotal,
            error: null,
            warnings: null,
          ),
        );
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: data['error'] ?? 'Validation failed',
      );
    } catch (e) {
      developer.log('Checkout validation error: $e', error: e);
      return ApiResult(
        statusCode: 500,
        error: e.toString(),
      );
    }
  }

  /// Pre-checkout stock validation for selected cart items or buy-now.
  /// POST /api/v1/checkout/validate-stock
  static Future<ApiResult> validateStock({
    String mode = 'cart',
    List<Map<String, dynamic>>? items,
    int? productId,
    int? variantId,
    int quantity = 1,
  }) async {
    try {
      final payload = <String, dynamic>{'mode': mode};
      if (mode == 'buy_now') {
        payload['product_id'] = productId;
        payload['variant_id'] = variantId;
        payload['quantity'] = quantity;
      } else {
        payload['items'] = items ?? [];
      }

      developer.log('Validating stock: $payload');

      final token = await ApiService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/validate-stock'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      developer.log(
          'Validate stock response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return ApiResult(statusCode: 200, data: data);
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: data['error']?.toString() ?? 'Stock validation failed',
        data: data,
      );
    } catch (e) {
      developer.log('Stock validation error: $e', error: e);
      return ApiResult(statusCode: 500, error: e.toString());
    }
  }

  /// Upload payment proof image (GCash screenshot)
  /// Returns URL and public_id for reference
  static Future<ApiResult> uploadPaymentProof({
    required String imagePath,
    Function(double)? onProgress,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return const ApiResult(
          statusCode: 400,
          error: 'File not found',
        );
      }

      developer.log('Uploading payment proof: $imagePath');
      
      // Get auth token
      final token = await ApiService.getToken();
      
      // Create multipart request
      const uploadUrl = 'https://eflora-system-production.up.railway.app/api/v1/checkout/upload-proof';
      
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );

      developer.log('Sending multipart upload to: $uploadUrl');
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      developer.log('Upload response status: ${response.statusCode}');
      developer.log('Upload response body: ${response.body}');
      
      if (onProgress != null) onProgress(1.0);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          return ApiResult(
            statusCode: 200,
            data: {
              'secure_url': data['url'] ?? '',  // Backend returns 'url', we map to 'secure_url'
              'public_id': data['public_id'] ?? '',
            },
          );
        } else {
          return ApiResult(
            statusCode: 400,
            error: data['error'] ?? 'Upload failed',
          );
        }
      } else {
        final data = jsonDecode(response.body);
        return ApiResult(
          statusCode: response.statusCode,
          error: data['error'] ?? 'Upload failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Payment proof upload error: $e', error: e);
      return ApiResult(
        statusCode: 500,
        error: 'Upload error: $e',
      );
    }
  }

  /// Create orders based on validated checkout
  /// This is the final step - creates Order records and reduces stock
  /// Supports per-store payment proofs via storePaymentProofs map
  static Future<ApiResult> createOrders({
    required int addressId,
    required String deliveryNotes,
    String? paymentProofUrl,
    String? paymentProofPublicId,
    Map<int, Map<String, String>>? storePaymentProofs,
    List<Map<String, dynamic>>? validatedOrders,
    Map<int, DateTime>? storeDeliveryDates,
    Map<int, String>? storeDeliveryTimes,
    Map<int, String>? storePaymentMethods,
  }) async {
    try {
      // Build per-store order data with individual payment proofs
      final ordersData = <Map<String, dynamic>>[];

      if (validatedOrders != null) {
        for (final order in validatedOrders) {
          final storeIdRaw = order['store_id'];
          final storeId = storeIdRaw is String ? int.parse(storeIdRaw) : (storeIdRaw as int);
          final paymentMethod =
              (storePaymentMethods?[storeId] ?? order['payment_method'] ?? 'gcash')
                  .toString()
                  .toLowerCase();
          final isCod = paymentMethod == 'cod';
          final orderEntry = <String, dynamic>{
            'store_id': storeId,
            'subtotal': order['subtotal'],
            'delivery_fee': order['delivery_fee'],
            'distance_km': order['distance_km'],
            'total': order['total'],
            'items': order['items'],
            'payment_method': isCod ? 'cod' : 'gcash',
            if (storeDeliveryDates != null && storeDeliveryDates.containsKey(storeId))
              'requested_delivery_date': DateFormat('yyyy-MM-dd').format(storeDeliveryDates[storeId]!),
            if (storeDeliveryTimes != null && storeDeliveryTimes.containsKey(storeId))
              'requested_delivery_time': storeDeliveryTimes[storeId],
          };

          // Per-store payment proof (GCash only)
          if (!isCod) {
            if (storePaymentProofs != null && storePaymentProofs.containsKey(storeId)) {
              orderEntry['payment_proof_url'] = storePaymentProofs[storeId]!['url'];
              orderEntry['payment_proof_public_id'] = storePaymentProofs[storeId]!['public_id'];
            } else if (paymentProofUrl != null) {
              // Fallback to single payment proof for all stores
              orderEntry['payment_proof_url'] = paymentProofUrl;
              orderEntry['payment_proof_public_id'] = paymentProofPublicId;
            }
          }

          ordersData.add(orderEntry);
        }
      }

      final payload = {
        'address_id': addressId,
        'delivery_notes': deliveryNotes,
        'orders': ordersData,
      };

      developer.log('Creating orders at $_baseUrl/create-orders: $payload');

      // Get auth token
      final token = await ApiService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Call the new per-store create-orders endpoint
      final response = await http.post(
        Uri.parse('$_baseUrl/create-orders'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      developer.log('Create orders response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
        // Parse orders from response
        final responseOrders = data['orders'] as List? ?? [];
        final orders = responseOrders
            .map((o) => Order.fromJson(o as Map<String, dynamic>))
            .toList();

        return ApiResult(
          statusCode: response.statusCode,
          data: {'orders': orders, 'message': data['message'] ?? 'Orders created successfully'},
        );
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: data['error'] ?? 'Failed to create orders',
      );
    } catch (e) {
      developer.log('Create orders error: $e', error: e);
      return ApiResult(
        statusCode: 500,
        error: 'Create orders error: $e',
      );
    }
  }

  /// Buy Now: Validate delivery for a single product (no cart)
  static Future<ApiResult> buyNowValidate({
    required int productId,
    int? variantId,
    required int quantity,
    required int addressId,
  }) async {
    try {
      final token = await ApiService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
        'delivery_address_id': addressId,
      };

      developer.log('Buy Now validate: $payload');

      final response = await http.post(
        Uri.parse('$_baseUrl/buy-now/validate'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      developer.log('Buy Now validate response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Build store order totals from orders (same as validateCheckout)
        final orders = data['orders'] as List? ?? [];
        final storeOrderTotals = <StoreOrderTotal>[];
        double grandTotal = 0;

        for (final order in orders) {
          final storeTotal = storeTotalFromOrder(Map<String, dynamic>.from(order as Map));
          storeOrderTotals.add(storeTotal);
          grandTotal += storeTotal.total;
        }

        return ApiResult(
          statusCode: 200,
          data: CheckoutValidationResponse(
            success: true,
            storeOrderTotals: storeOrderTotals,
            grandTotal: grandTotal,
            error: null,
            warnings: null,
          ),
        );
      }

      final warnings = <String>[];
      final undeliverable = data['undeliverable_stores'] as List? ?? [];
      for (final store in undeliverable) {
        if (store is Map) {
          final name = store['store_name'] ?? 'Store';
          final reason = store['reason'];
          warnings.add(
            reason != null && reason.toString().trim().isNotEmpty
                ? '$name: $reason'
                : name.toString(),
          );
        }
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: data['error'] ?? 'Validation failed',
        data: CheckoutValidationResponse(
          success: false,
          storeOrderTotals: [],
          grandTotal: 0,
          error: data['error'] as String?,
          warnings: warnings.isEmpty ? null : warnings,
        ),
      );
    } catch (e) {
      developer.log('Buy Now validate error: $e', error: e);
      return ApiResult(statusCode: 500, error: 'Buy Now validate error: $e');
    }
  }

  /// Buy Now: Create order directly from product data (no cart)
  static Future<ApiResult> buyNowCreateOrder({
    required int productId,
    int? variantId,
    required int quantity,
    required int addressId,
    required String deliveryNotes,
    required DateTime deliveryDate,
    required String deliveryTime,
    String? paymentProofUrl,
    String? paymentProofPublicId,
    String paymentMethod = 'gcash',
  }) async {
    try {
      final token = await ApiService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
        'address_id': addressId,
        'delivery_notes': deliveryNotes,
        'requested_delivery_date': DateFormat('yyyy-MM-dd').format(deliveryDate),
        'requested_delivery_time': deliveryTime,
        'payment_method': paymentMethod == 'cod' ? 'cod' : 'gcash',
        if (paymentMethod != 'cod') ...{
          'payment_proof_url': paymentProofUrl,
          'payment_proof_public_id': paymentProofPublicId,
        },
      };

      developer.log('Buy Now create order: $payload');

      final response = await http.post(
        Uri.parse('$_baseUrl/buy-now/create-order'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      developer.log('Buy Now create order response: ${response.statusCode} - ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
        final ordersData = data['orders'] as List? ?? [];
        final orders = ordersData
            .map((o) => Order.fromJson(o as Map<String, dynamic>))
            .toList();

        return ApiResult(
          statusCode: response.statusCode,
          data: {'orders': orders, 'message': data['message'] ?? 'Order created successfully'},
        );
      }

      return ApiResult(
        statusCode: response.statusCode,
        error: data['error'] ?? 'Failed to create order',
      );
    } catch (e) {
      developer.log('Buy Now create order error: $e', error: e);
      return ApiResult(statusCode: 500, error: 'Buy Now create order error: $e');
    }
  }

  /// Toggle cart item selection (some items can be excluded from checkout)
  static Future<ApiResult> toggleCartItemSelection(int cartItemId) async {
    return ApiService.toggleCartItemSelection(cartItemId);
  }

  /// Toggle all items from a specific store
  static Future<ApiResult> toggleStoreSelection(int storeId, bool selected) async {
    return ApiService.toggleStoreSelection(storeId, selected);
  }

  /// Get available delivery slots (synchronous fallback)
  static List<String> getAvailableTimeSlots() {
    return [
      '08:00-12:00', // 8 AM - 12 PM
      '12:00-15:00', // 12 PM - 3 PM
      '15:00-18:00', // 3 PM - 6 PM
    ];
  }

  /// Fetch store-specific time slots from API
  static Future<Map<String, dynamic>> fetchStoreTimeSlots(int storeId, String date) async {
    try {
      final token = await ApiService.getToken();
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(
        'https://eflora-system-production.up.railway.app/api/v1/customer/stores/$storeId/time-slots?date=$date',
      );

      developer.log('Fetching time slots: $uri');

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      developer.log('Time slots response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final slots = (data['time_slots'] as List)
            .map((s) => s['value'] as String)
            .toList();
        final labels = Map.fromEntries(
          (data['time_slots'] as List).map(
            (s) => MapEntry(s['value'] as String, s['label'] as String),
          ),
        );
        return {
          'success': true,
          'slots': slots,
          'labels': labels,
          'is_open': data['is_open'] ?? false,
          'has_schedule': data['has_schedule'] ?? false,
          'block_reason': asBlockReason(data['block_reason']),
          'order_cutoff': data['order_cutoff'],
          'open_days': (data['open_days'] as List?)
                  ?.map((day) => day.toString().toLowerCase())
                  .toList() ??
              const <String>[],
        };
      }

      return {
        'success': false,
        'slots': <String>[],
        'is_open': false,
        'has_schedule': false,
      };
    } catch (e) {
      developer.log('Error fetching store time slots: $e', error: e);
      return {
        'success': false,
        'slots': <String>[],
        'is_open': false,
        'has_schedule': false,
      };
    }
  }

  /// Get Philippine timezone (UTC+8)
  static DateTime getPhilippineTime() {
    final utcNow = DateTime.now().toUtc();
    // Add 8 hours for Philippine timezone (UTC+8)
    return utcNow.add(const Duration(hours: 8));
  }

  /// Start-of-day helper in Philippine local date.
  static DateTime normalizeToPhDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Build a 14-day selectable range (today + next 13 days) in PH date.
  static List<DateTime> getAvailableDeliveryDateRange({int days = 14}) {
    final phNow = getPhilippineTime();
    final start = normalizeToPhDate(phNow);
    return List<DateTime>.generate(
      days,
      (i) => start.add(Duration(days: i)),
    );
  }

  /// Human label for date chips.
  static String formatDeliveryDateLabel(DateTime date) {
    final phNow = getPhilippineTime();
    final today = normalizeToPhDate(phNow);
    final target = normalizeToPhDate(date);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE').format(target).toUpperCase();
  }

  /// Month short label (JAN, FEB...).
  static String formatDeliveryMonth(DateTime date) =>
      DateFormat('MMM').format(date).toUpperCase();

  /// Day number label.
  static String formatDeliveryDay(DateTime date) =>
      date.day.toString().padLeft(2, '0');

  /// Format time slot for display (08:00-12:00 → 8:00 AM - 12:00 PM)
  static String formatTimeSlot(String timeSlot) {
    try {
      final parts = timeSlot.split('-');
      if (parts.length != 2) return timeSlot;

      final startTime = DateFormat('HH:mm').parse(parts[0].trim());
      final endTime = DateFormat('HH:mm').parse(parts[1].trim());

      final start = DateFormat('h:mm a').format(startTime);
      final end = DateFormat('h:mm a').format(endTime);

      return '$start - $end';
    } catch (e) {
      return timeSlot;
    }
  }

  /// Check if a time slot has already started (for today, Philippine time).
  static bool isTimeSlotPassed(String timeSlot) {
    try {
      final phTime = getPhilippineTime();
      final currentMinutes = phTime.hour * 60 + phTime.minute;

      final parts = timeSlot.split('-');
      if (parts.length != 2) return false;

      final startTime = DateFormat('HH:mm').parse(parts[0].trim());
      final startMinutes = startTime.hour * 60 + startTime.minute;

      return currentMinutes >= startMinutes;
    } catch (e) {
      return false;
    }
  }

  static String? asBlockReason(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static bool isPastOrderCutoff(dynamic cutoff) {
    final raw = cutoff?.toString().trim() ?? '';
    if (raw.isEmpty) return false;
    try {
      final parts = raw.split(':');
      if (parts.length < 2) return false;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = getPhilippineTime();
      return (now.hour * 60 + now.minute) >= (hour * 60 + minute);
    } catch (_) {
      return false;
    }
  }

  /// Match web checkout copy in base.html `reasonMessage()`.
  static String slotBlockMessage(String? reason) {
    switch (reason) {
      case 'no_schedule':
        return 'This store has not set delivery hours yet.';
      case 'order_cutoff':
        return 'Same-day ordering is closed. Please choose another open day.';
      case 'lead_time':
        return 'Remaining slots are inside the prep window. Please choose a later slot or another date.';
      case 'slots_passed':
        return 'All delivery slots for today have passed. Please select another open day.';
      default:
        return 'Store is closed on this day. Please select a different date.';
    }
  }

  static String? resolveSlotBlockReason({
    required dynamic apiReason,
    required bool isToday,
    required bool isOpen,
    required bool hasSchedule,
    required bool hasBookableSlots,
    dynamic orderCutoff,
    List<String>? openDays,
    DateTime? date,
  }) {
    if (hasBookableSlots) return null;
    final reason = asBlockReason(apiReason);
    if (reason == 'no_schedule' || reason == 'lead_time') return reason;
    if (!hasSchedule) return 'no_schedule';

    final weekday = date == null
        ? null
        : DateFormat('EEEE').format(date).toLowerCase();
    final scheduledOpen = weekday == null ||
        (openDays == null || openDays.isEmpty) ||
        openDays.contains(weekday);

    if (isToday &&
        scheduledOpen &&
        (reason == 'order_cutoff' || isPastOrderCutoff(orderCutoff))) {
      return 'order_cutoff';
    }
    if (reason != null) return reason;
    if (!isOpen) return 'closed';
    if (isToday) return 'slots_passed';
    return 'closed';
  }

  /// Map create-order API errors to the same short web checkout warnings.
  static String humanizeDeliverySlotError(String? error) {
    final raw = (error ?? '').trim();
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    if (lower.contains('same-day ordering')) {
      return slotBlockMessage('order_cutoff');
    }
    if (lower.contains('prep window') || lower.contains('in advance')) {
      return slotBlockMessage('lead_time');
    }
    if (lower.contains('already passed') ||
        (lower.contains('slots') && lower.contains('passed'))) {
      return slotBlockMessage('slots_passed');
    }
    if (lower.contains('has not configured delivery hours') ||
        lower.contains('has not set delivery hours')) {
      return slotBlockMessage('no_schedule');
    }
    if (lower.contains('is closed on the selected date') ||
        lower.contains('store is closed')) {
      return slotBlockMessage('closed');
    }
    return raw;
  }
}

  /// Check if a store delivers to a customer address (radius, customzone, municipality).
  static Future<Map<String, dynamic>> checkStoreDelivery({
    required int storeId,
    int? addressId,
    double subtotal = 100.0,
  }) async {
    try {
      var uriStr = '$_api/stores/$storeId/check-delivery?subtotal=$subtotal';
      if (addressId != null) uriStr += '&address_id=$addressId';
      final res = await http.get(
        Uri.parse(uriStr),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'can_deliver': false, 'reason': 'Failed to verify delivery coverage.'};
    } catch (e) {
      print('❌ ChatService.checkStoreDelivery error: $e');
      return {'can_deliver': false, 'reason': 'Error checking store delivery coverage.'};
    }
  }

  /// Checkout a custom arrangement ticket (Customer action).
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Change this to your machine's LAN IP when testing on a real device ──
  // Android emulator  → 10.0.2.2:5000
  // iOS simulator     → localhost:5000
  // Real device       → 192.168.x.x:5000 (currently: 192.168.1.9)
  static const String _base = 'https://eflora-system-production.up.railway.app';
  static const String _api  = '$_base/api/v1';

  /// Public API root for unauthenticated config endpoints.
  static String get apiRoot => _api;

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('jwt_token');
    await p.remove('user_data');
  }

  /// ✅ DEPRECATED: Use addToCart() instead (supports variants via optional parameter)
  @Deprecated('Use addToCart(productId, qty, variantId: variantId) instead')
  static Future<ApiResult> addToCartWithVariant(int productId, int variantId, int qty) async {
    return addToCart(productId, qty, variantId: variantId);
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) {
        h['Authorization'] = 'Bearer $t';
        print('🔑 Adding auth token: Bearer ${t.substring(0, 20)}...');
      }
    }
    return h;
  }

  /// Full URL for a static asset path from the server
  static String assetUrl(String path) {
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) {
      return '$_base$path';
    }
    return '$_base/$path';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> login(String email, String password) async {
    try {
      print('🔵 ATTEMPTING LOGIN');
      print('📡 Full URL: $_api/auth/login');
      
      final res = await http.post(
        Uri.parse('$_api/auth/login'),
        headers: await _headers(),
        body: jsonEncode({'identifier': email, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['token'] != null) {
        await saveToken(data['token'] as String);
        // Cache user data
        final p = await SharedPreferences.getInstance();
        await p.setString('user_data', jsonEncode(data));
        print('✅ Login successful, token saved');
        
        // 🔍 DEBUG: Auto-check token after login
        await debugPrintToken();
        await debugCheckTokenWithServer();
      }
      return ApiResult(statusCode: res.statusCode, data: data);
    } catch (e) {
      print('❌ Login error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 ATTEMPTING REGISTRATION');
      print('📡 Full URL: $_api/auth/register');
      
      final res = await http.post(
        Uri.parse('$_api/auth/register'),
        headers: await _headers(),
        body: jsonEncode({'full_name': fullName, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 && data['token'] != null) {
        await saveToken(data['token'] as String);
        final p = await SharedPreferences.getInstance();
        await p.setString('user_data', jsonEncode(data));
        print('✅ Registration successful, token saved');
        
        // 🔍 DEBUG: Auto-check token after registration
        await debugPrintToken();
        await debugCheckTokenWithServer();
      }
      return ApiResult(statusCode: res.statusCode, data: data);
    } catch (e) {
      print('❌ Registration error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Customer OTP registration ─────────────────────────────────────────────

  /// Step 1 — send a 6-digit OTP via email or SMS from a single identifier.
  static Future<ApiResult> sendCustomerOtp({
    required String fullName,
    required String identifier,
    required String password,
    bool agreeTerms = false,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/customer/send-otp'),
        headers: await _headers(),
        body: jsonEncode({
          'full_name': fullName,
          'identifier': identifier,
          'password': password,
          'agree_terms': agreeTerms,
        }),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Step 2a — verify the OTP the customer received.
  static Future<ApiResult> verifyCustomerOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/customer/verify-otp'),
        headers: await _headers(),
        body: jsonEncode({'email': email, 'otp_code': otpCode}),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Step 2b — request a fresh OTP (resend).
  static Future<ApiResult> resendCustomerOtp({required String email}) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/customer/resend-otp'),
        headers: await _headers(),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Step 3 — finalise registration after OTP is verified.
  static Future<ApiResult> registerCustomerAfterOtp({required String email}) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/customer/register'),
        headers: await _headers(),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Web-aligned flow: do not auto-login after OTP registration.
      // The app should route user to Sign In and let them authenticate manually.
      return ApiResult(statusCode: res.statusCode, data: data);
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ── Forgot password (email → Gmail OTP, phone → SMS OTP) ───────────────────

  static Future<ApiResult> sendForgotPasswordOtp({
    String? email,
    String? identifier,
  }) async {
    try {
      final id = (identifier ?? email ?? '').trim();
      final res = await http.post(
        Uri.parse('$_api/auth/forgot-password/send-otp'),
        headers: await _headers(),
        body: jsonEncode({
          'identifier': id,
          // Back-compat for older servers
          if (id.contains('@')) 'email': id.toLowerCase(),
        }),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> resendForgotPasswordOtp({required String email}) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/forgot-password/resend-otp'),
        headers: await _headers(),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> verifyForgotPasswordOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/forgot-password/verify-otp'),
        headers: await _headers(),
        body: jsonEncode({'email': email, 'otp_code': otpCode}),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> resetPasswordAfterOtp({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/forgot-password/reset'),
        headers: await _headers(),
        body: jsonEncode({
          'email': email,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────

  static Future<ApiResult> getMe() async {
    try {
      print('🔵 GETTING USER INFO');
      final res = await http.get(
        Uri.parse('$_api/auth/me'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetMe error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> updateProfile({
    required String firstName,
    required String lastName,
    String? birthday,
    String? gender,
  }) async {
    try {
      print('🔵 UpdateProfile: sending to $_api/auth/profile/update');
      final res = await http.post(
        Uri.parse('$_api/auth/profile/update'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          if (birthday != null) 'birthday': birthday,
          if (gender != null) 'gender': gender,
        }),
      ).timeout(const Duration(seconds: 20));
      
      print('📨 UpdateProfile response status: ${res.statusCode}');
      print('📨 UpdateProfile response body: ${res.body}');
      
      if (res.body.isEmpty) {
        return ApiResult(statusCode: res.statusCode, error: 'Empty response from server');
      }
      
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ UpdateProfile error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static ApiResult _parseHttp(http.Response res) {
    final raw = res.body;
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('<!') || trimmed.toLowerCase().startsWith('<html')) {
      return ApiResult(
        statusCode: res.statusCode == 0 ? 502 : res.statusCode,
        error: 'Could not reach the phone verification service. Please try again.',
      );
    }
    if (raw.isEmpty) {
      return ApiResult(statusCode: res.statusCode, error: 'Empty response from server');
    }
    try {
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(raw));
    } on FormatException {
      return ApiResult(
        statusCode: res.statusCode,
        error: 'Could not reach the phone verification service. Please try again.',
      );
    }
  }

  static Future<ApiResult> getFeatureFlags() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/auth/feature-flags'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      return _parseHttp(res);
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> sendProfilePhoneOtp({required String phone}) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/profile/phone/send-otp'),
        headers: await _headers(auth: true),
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 20));
      return _parseHttp(res);
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Could not send the code. Check your connection and try again.');
    }
  }

  static Future<ApiResult> verifyProfilePhoneOtp({required String otpCode}) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/profile/phone/verify'),
        headers: await _headers(auth: true),
        body: jsonEncode({'otp_code': otpCode}),
      ).timeout(const Duration(seconds: 20));
      return _parseHttp(res);
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Could not verify the code. Check your connection and try again.');
    }
  }

  static Future<ApiResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      print('🔵 ChangePassword: sending to $_api/auth/password/change');
      final res = await http.post(
        Uri.parse('$_api/auth/password/change'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      
      print('📨 ChangePassword response status: ${res.statusCode}');
      print('📨 ChangePassword response body: ${res.body}');
      
      if (res.body.isEmpty) {
        return ApiResult(statusCode: res.statusCode, error: 'Empty response from server');
      }
      
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ ChangePassword error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> deleteAccount({
    required String password,
    String confirmation = 'DELETE',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/auth/account/delete'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'password': password,
          'current_password': password,
          'confirmation': confirmation,
        }),
      ).timeout(const Duration(seconds: 20));
      return _parseHttp(res);
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> uploadAvatar(File imageFile) async {
    try {
      print('🔵 UploadAvatar: sending to $_base/api/cloudinary/user/avatar');
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/api/cloudinary/user/avatar'),
      );
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        print('🔑 Adding auth token: Bearer ${token.substring(0, 20)}...');
      }
      
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      final res = await request.send().timeout(const Duration(seconds: 30));
      final resBody = await res.stream.bytesToString();
      
      print('📨 UploadAvatar response status: ${res.statusCode}');
      print('📨 UploadAvatar response body: $resBody');
      
      if (resBody.isEmpty) {
        return ApiResult(statusCode: res.statusCode, error: 'Empty response from server');
      }
      
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(resBody));
    } catch (e) {
      print('❌ UploadAvatar error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getProducts({
    String? category,
    int? storeId,
    String? search,
    int page = 1,
    int perPage = 40,
    bool? includeOutsideLocation,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (category != null && category != 'all') params['category'] = category;
      if (storeId  != null) params['store_id'] = storeId.toString();
      if (search   != null && search.isNotEmpty) params['q'] = search;
      if (includeOutsideLocation != null) {
        params['include_outside_location'] = includeOutsideLocation ? '1' : '0';
      }
      final uri = Uri.parse('$_api/customer/products').replace(queryParameters: params);
      print('📡 Getting products: $uri');
      final res = await http.get(uri, headers: await _headers(auth: true)).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetProducts error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Fetch all main categories from API
  /// Maps to: /api/laguna/municipalities or similar endpoint for categories
  static Future<ApiResult> getCategories() async {
    try {
      print('📂 Fetching categories...');
      const url = '$_api/customer/categories';  // Categories endpoint under customer API
      print('📡 URL: $url');
      
      final res = await http.get(
        Uri.parse(url),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      
      print('📡 Response status: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        print('✅ Categories loaded: $data');
        return ApiResult(statusCode: res.statusCode, data: data);
      } else {
        print('❌ Failed to load categories: ${res.body}');
        return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
      }
    } catch (e) {
      print('❌ GetCategories error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getProduct(int id) async {
    try {
      print('📡 Getting product: $id');
      final res = await http.get(
        Uri.parse('$_api/customer/products/$id'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetProduct error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STORES
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getStores({bool? includeOutsideLocation}) async {
    try {
      print('📡 Getting stores');
      final params = <String, String>{};
      if (includeOutsideLocation != null) {
        params['include_outside_location'] = includeOutsideLocation ? '1' : '0';
      }
      final uri = Uri.parse('$_api/customer/stores').replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(
        uri,
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetStores error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getStore(int storeId) async {
    try {
      print('📡 Getting store detail: $storeId');
      // Send JWT when available so backend can attach default-address
      // delivery coverage + customer map pin (same as web store detail).
      final res = await http.get(
        Uri.parse('$_api/customer/stores/$storeId'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetStore error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getStoreCategories(int storeId) async {
    try {
      print('📡 Getting store categories: $storeId');
      final res = await http.get(
        Uri.parse('$_api/customer/stores/$storeId/categories'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetStoreCategories error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CART - FIXED URLs matching customer.py exactly
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getCart() async {
    try {
      print('🛒 Getting cart');
      // CORRECT: Use the customer blueprint URL
      const url = '$_api/customer/cart';  // ← This matches @customer_bp.route('/cart')
      print('📡 URL: $url');
      final res = await http.get(
        Uri.parse(url),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetCart error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

 /// ✅ UNIFIED ADD TO CART - Supports both main products and variants
/// 
/// Parameters:
///   - [productId]: The product ID (required)
///   - [qty]: Quantity to add (required, default 1)
///   - [variantId]: Variant ID if adding a variant (optional)
/// 
/// Returns: ApiResult with cart item data on success
/// 
/// Matches Web Implementation:
///   - Payload structure: {product_id, quantity, [variant_id]}
///   - Error handling: Comprehensive logging
///   - Classifications: Detects variant vs main product
  static Future<ApiResult> addToCart(
    int productId,
    int qty, {
    int? variantId,
    List<int>? addonOptionIds,
  }) async {
  try {
    // ════════════════════════════════════════════════════════════════
    // CLASSIFICATION: Determine if this is a variant or main product
    // ════════════════════════════════════════════════════════════════
    final isVariant = variantId != null;
    print('🛒 ┌─ ADD TO CART (UNIFIED)');
    print('🛒 │  Product Classification');
    print('🛒 │  ├─ Is Variant: $isVariant');
    print('🛒 │  ├─ Product ID: $productId');
    print('🛒 │  ├─ Variant ID: ${variantId ?? "none (main product)"}');
    print('🛒 │  └─ Quantity: $qty');
    
    // ════════════════════════════════════════════════════════════════
    // BUILD PAYLOAD - Mirroring Web Implementation
    // ════════════════════════════════════════════════════════════════
    const url = '$_api/customer/cart/items';  
    print('🛒 │');
    print('🛒 │  Request Details');
    print('🛒 │  ├─ Method: POST');
    print('🛒 │  └─ URL: $url');
    
    // Create body with or without variant_id (same as web)
    Map<String, dynamic> bodyMap = {
      'product_id': productId,  
      'quantity': qty           
    };
    
    // ✅ Include variant_id only if present (matches web pattern)
    if (variantId != null) {
      bodyMap['variant_id'] = variantId;
      print('🛒 │');
      print('🛒 │  Payload includes variant_id: $variantId');
    }
    if (addonOptionIds != null && addonOptionIds.isNotEmpty) {
      bodyMap['addon_option_ids'] = addonOptionIds;
    }
    
    final body = jsonEncode(bodyMap);
    print('🛒 │  Payload: $body');
    
    // ════════════════════════════════════════════════════════════════
    // SEND REQUEST - With comprehensive error handling
    // ════════════════════════════════════════════════════════════════
    print('🛒 │');
    print('🛒 │  Sending request...');
    
    final res = await http.post(
      Uri.parse(url),
      headers: await _headers(auth: true),
      body: body,
    ).timeout(const Duration(seconds: 10));
    
    print('🛒 │  Response Status: ${res.statusCode}');
    print('🛒 │  Response Body: ${res.body}');
    
    final resultData = jsonDecode(res.body);
    
    if (res.statusCode == 201 || res.statusCode == 200) {
      print('🛒 ├─ ✅ SUCCESS - Item added to cart');
      print('🛒 └─ Data: $resultData');
    } else {
      print('🛒 └─ ⚠️ ERROR - Server returned ${res.statusCode}');
    }
    
    return ApiResult(statusCode: res.statusCode, data: resultData);
  } catch (e) {
    print('🛒 └─ ❌ NETWORK ERROR: $e');
    return ApiResult(statusCode: 0, error: 'Network error: $e');
  }
}

  static Future<ApiResult> updateCartItem(int itemId, int qty) async {
    try {
      print('🛒 Updating cart item: itemId=$itemId, qty=$qty');
      final url = '$_api/customer/cart/items/$itemId';
      print('📡 URL: $url');
      final res = await http.put(
        Uri.parse(url),
        headers: await _headers(auth: true),
        body: jsonEncode({'quantity': qty}),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ UpdateCartItem error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> removeFromCart(int itemId) async {
    try {
      print('🛒 Removing from cart: itemId=$itemId');
      final url = '$_api/customer/cart/items/$itemId';
      print('📡 URL: $url');
      final res = await http.delete(
        Uri.parse(url),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ RemoveFromCart error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Remove one structured add-on from a cart line (web cart parity).
  static Future<ApiResult> removeCartAddon(int itemId, int addonOptionId) async {
    try {
      final url = '$_api/customer/cart/items/$itemId/addons/$addonOptionId';
      final res = await http.delete(
        Uri.parse(url),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> clearCart() async {
    try {
      print('🛒 Clearing cart');
      const url = '$_api/customer/cart/clear';
      print('📡 URL: $url');
      final res = await http.post(
        Uri.parse(url),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ ClearCart error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Toggle selection of a single cart item
  static Future<ApiResult> toggleCartItemSelection(int itemId) async {
    try {
      print('🛒 Toggling cart item selection: itemId=$itemId');
      final url = '$_api/checkout/cart/items/$itemId/toggle';
      print('📡 URL: $url');
      final res = await http.put(
        Uri.parse(url),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ ToggleCartItem error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Toggle selection of all cart items from a specific store
  static Future<ApiResult> toggleStoreSelection(int storeId, bool selected) async {
    try {
      print('🛒 Toggling store selection: storeId=$storeId, selected=$selected');
      final url = '$_api/checkout/cart/store/$storeId/toggle';
      print('📡 URL: $url');
      final res = await http.put(
        Uri.parse(url),
        headers: await _headers(auth: true),
        body: jsonEncode({'selected': selected}),
      ).timeout(const Duration(seconds: 10));
      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ ToggleStoreSelection error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WISHLIST
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getWishlist() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/wishlist'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getWishlistForProduct(int productId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/wishlist/product/$productId'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> toggleWishlist(int productId, {int? variantId}) async {
    try {
      final body = <String, dynamic>{'product_id': productId};
      if (variantId != null) body['variant_id'] = variantId;
      final res = await http.post(
        Uri.parse('$_api/customer/wishlist/toggle'),
        headers: await _headers(auth: true),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> removeWishlistItem(int itemId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_api/customer/wishlist/$itemId'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ORDERS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getOrders({String? status, int page = 1}) async {
    try {
      final params = <String, String>{'page': page.toString()};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final uri = Uri.parse('$_api/customer/orders').replace(queryParameters: params);
      print('📡 Getting orders: $uri');
      final res = await http.get(uri, headers: await _headers(auth: true)).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetOrders error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getOrder(int id) async {
    try {
      print('📡 Getting order: $id');
      final res = await http.get(
        Uri.parse('$_api/customer/orders/$id'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ GetOrder error: $e');
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getOrderTracking(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/orders/$id/tracking'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> completeOrder(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/customer/orders/$id/complete'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> cancelOrder(
    int id, {
    required String reasonCode,
    String? reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/customer/orders/$id/cancel'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'reason_code': reasonCode,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RATINGS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getOrderRatings(int orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/orders/$orderId/ratings'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Submit product line ratings and/or a single store experience rating for the order.
  static Future<ApiResult> submitOrderRatings(
    int orderId, {
    List<Map<String, dynamic>>? ratings,
    Map<String, dynamic>? storeRating,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (ratings != null && ratings.isNotEmpty) {
        body['ratings'] = ratings;
      }
      if (storeRating != null && storeRating.isNotEmpty) {
        body['store_rating'] = storeRating;
      }
      if (body.isEmpty) {
        return ApiResult(statusCode: 400, data: {'error': 'Nothing to submit'});
      }
      final res = await http.post(
        Uri.parse('$_api/customer/orders/$orderId/rate'),
        headers: await _headers(auth: true),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> getProductRatings(
    int productId, {
    int page = 1,
    int perPage = 50,
    /// null = all; use `'main'` for standard product; int for a variant id
    Object? variantId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (variantId != null) {
        params['variant_id'] = variantId.toString();
      }
      final uri = Uri.parse('$_api/customer/products/$productId/ratings')
          .replace(queryParameters: params);
      final res = await http.get(
        uri,
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SELLER APPLICATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getSellerApplication() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/seller-application'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> submitSellerApplication({
    required String storeName,
    required String storeDescription,
    required String storeLogoUrl,
    required String storeLogoPublicId,
    required String governmentIdUrl,
    required String governmentIdPublicId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/customer/seller-application'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'store_name': storeName,
          'store_description': storeDescription,
          'store_logo_url': storeLogoUrl,
          'store_logo_public_id': storeLogoPublicId,
          'government_id_url': governmentIdUrl,
          'government_id_public_id': governmentIdPublicId,
        }),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> resubmitSellerApplication(Map<String, dynamic> updatedFields) async {
    try {
      final res = await http.put(
        Uri.parse('$_api/customer/seller-application/resubmit'),
        headers: await _headers(auth: true),
        body: jsonEncode(updatedFields),
      ).timeout(const Duration(seconds: 15));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  /// Upload an image for seller application (store logo or government ID)
  static Future<ApiResult> uploadSellerDocument(File imageFile, String folder) async {
    try {
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_api/cloudinary/upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final res = await request.send().timeout(const Duration(seconds: 30));
      final resBody = await res.stream.bytesToString();

      if (resBody.isEmpty) {
        return ApiResult(statusCode: res.statusCode, error: 'Empty response');
      }
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(resBody));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResult> getNotifications() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/customer/notifications'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> markNotificationRead(int notifId) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/customer/notifications/$notifId/read'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  static Future<ApiResult> markAllNotificationsRead() async {
    try {
      final res = await http.post(
        Uri.parse('$_api/customer/notifications/read-all'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      return ApiResult(statusCode: 0, error: 'Network error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔍 DEBUG METHODS
  // ══════════════════════════════════════════════════════════════════════════

static Future<ApiResult> debugCheckImage(String filename) async {
  try {
    print('🔍 Checking image: $filename');
    final res = await http.get(
      Uri.parse('$_base/debug/check-image/$filename'),
    ).timeout(const Duration(seconds: 5));
    
    print('📡 Image check response: ${res.statusCode}');
    print('📡 Response body: ${res.body}');
    
    return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
  } catch (e) {
    print('❌ Image check error: $e');
    return ApiResult(statusCode: 0, error: e.toString());
  }
}
  static Future<void> debugPrintToken() async {
    print('\n🔍 TOKEN DEBUG INFO');
    print('=' * 50);
    
    final token = await getToken();
    if (token == null) {
      print('❌ No token found');
      print('=' * 50);
      return;
    }
    
    print('✅ Token exists (first 50 chars): ${token.substring(0, 50)}...');
    
    // Try to decode the token locally
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        print('📦 Token payload: $payload');
        print('✅ Has "sub" claim: ${payload.containsKey('sub')}');
        if (payload.containsKey('sub')) {
          print('   sub value: ${payload['sub']}');
          print('   role: ${payload['role']}');
          print('   email: ${payload['email']}');
        }
      } else {
        print('❌ Token has invalid format (not 3 parts)');
      }
    } catch (e) {
      print('❌ Failed to decode token: $e');
    }
    
    print('=' * 50);
  }

  static Future<ApiResult> debugCheckTokenWithServer() async {
    try {
      print('🔍 Checking token with server...');
      final res = await http.get(
        Uri.parse('$_api/auth/debug/check-token'),
        headers: await _headers(auth: true),
      ).timeout(const Duration(seconds: 10));
      
      print('📡 Server response: ${res.statusCode}');
      print('📡 Response body: ${res.body}');
      
      return ApiResult(statusCode: res.statusCode, data: jsonDecode(res.body));
    } catch (e) {
      print('❌ Debug error: $e');
      return ApiResult(statusCode: 0, error: e.toString());
    }
  }
}

class ApiResult {
  final int statusCode;
  final dynamic data;
  final String? error;

  const ApiResult({required this.statusCode, this.data, this.error});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  String? get errorMessage => error ?? (data is Map ? (data['error'] ?? data['message']) : null);
}











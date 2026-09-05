import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;
  String? _lastErrorCode;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  String? get lastErrorCode => _lastErrorCode;

  // ── Restore session on app start ────────────────────────────────────
  Future<void> tryAutoLogin() async {
    final p = await SharedPreferences.getInstance();
    final token    = p.getString('jwt_token');
    final userData = p.getString('user_data');

    if (token == null) return;

    // Restore from cache immediately for instant UX
    if (userData != null) {
      try {
        final raw = jsonDecode(userData) as Map<String, dynamic>;
        final userMap = raw['user'] as Map<String, dynamic>? ?? raw;
        _user = User.fromJson(userMap);
        notifyListeners();
      } catch (_) {}
    }

    // Validate token with server
    final result = await ApiService.getMe();
    if (result.isSuccess && result.data is Map) {
      _user = User.fromJson(result.data as Map<String, dynamic>);
      notifyListeners();
    } else if (result.statusCode == 401) {
      await logout(notify: true);
    }
    // Other errors (network down etc.) → keep cached user logged in
  }

  // ── Login ────────────────────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();

    final result = await ApiService.login(email, password);
    _loading = false;

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      final userMap = d['user'] as Map<String, dynamic>? ?? d;
      _user = User.fromJson(userMap);

      final p = await SharedPreferences.getInstance();
      await p.setString('user_data', jsonEncode(d));

      notifyListeners();
      // Login payloads can be partial — pull full profile (avatar, etc.)
      await refreshUser();
      return null;
    }

    _error = result.errorMessage ?? 'Login failed';
    notifyListeners();
    return _error;
  }

  // ── Register (legacy — direct, no OTP) ───────────────────────────────
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _loading = true; _error = null; notifyListeners();

    final result = await ApiService.register(
      fullName: fullName, email: email, password: password,
    );
    _loading = false;

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      final userMap = d['user'] as Map<String, dynamic>? ?? d;
      _user = User.fromJson(userMap);

      final p = await SharedPreferences.getInstance();
      await p.setString('user_data', jsonEncode(d));

      notifyListeners();
      return null;
    }

    _error = result.errorMessage ?? 'Registration failed';
    notifyListeners();
    return _error;
  }

  // ── OTP-verified customer registration (3-step) ───────────────────────
  //
  //   Step 1: sendOtp()              → POST /auth/customer/send-otp
  //   Step 2: verifyOtp()            → POST /auth/customer/verify-otp
  //   Step 3: registerAfterOtp()     → POST /auth/customer/register
  //   Extra : resendOtp()            → POST /auth/customer/resend-otp

  /// Returns null on success, or an error string on failure.
  /// On success, [lastSendOtpMeta] holds account email / channel / login_id.
  Map<String, dynamic>? lastSendOtpMeta;

  Future<String?> sendOtp({
    required String fullName,
    required String identifier,
    required String password,
    bool agreeTerms = false,
  }) async {
    _loading = true; _error = null; _lastErrorCode = null;
    lastSendOtpMeta = null;
    notifyListeners();
    final result = await ApiService.sendCustomerOtp(
      fullName: fullName,
      identifier: identifier,
      password: password,
      agreeTerms: agreeTerms,
    );
    _loading = false;
    final data = result.data is Map ? result.data as Map<String, dynamic> : null;
    if (result.statusCode == 200) {
      lastSendOtpMeta = data;
      notifyListeners();
      return null;
    }
    _lastErrorCode = data?['error_code']?.toString();
    _error = result.errorMessage ?? 'Failed to send verification code';
    notifyListeners();
    return _error;
  }

  /// Returns null on success, or an error string on failure.
  /// [attemptsRemaining] and [expired]/[locked] are populated on failure.
  Future<Map<String, dynamic>?> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.verifyCustomerOtp(email: email, otpCode: otpCode);
    _loading = false;
    final data = result.data as Map<String, dynamic>? ?? {};
    if (result.statusCode == 200 && data['verified'] == true) {
      notifyListeners();
      return null;   // success
    }
    _error = data['error'] as String? ?? result.errorMessage ?? 'Verification failed';
    notifyListeners();
    return data;  // caller can inspect expired / locked / attempts_remaining
  }

  /// Returns null on success (account created; user must sign in manually),
  /// or an error string.
  Future<String?> registerAfterOtp({required String email}) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.registerCustomerAfterOtp(email: email);
    _loading = false;

    if (result.statusCode == 201) {
      notifyListeners();
      return null;
    }

    _error = result.errorMessage ?? 'Account creation failed';
    notifyListeners();
    return _error;
  }

  /// Returns null on success, or an error string with optional [retryAfterSeconds].
  Future<Map<String, dynamic>?> resendOtp({required String email}) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.resendCustomerOtp(email: email);
    _loading = false;
    final data = result.data as Map<String, dynamic>? ?? {};
    if (result.statusCode == 200) { notifyListeners(); return null; }
    _lastErrorCode = data['error_code']?.toString();
    _error = data['error'] as String? ?? result.errorMessage ?? 'Failed to resend code';
    notifyListeners();
    return data;
  }

  // ── Forgot password (email or phone identifier) ────────────────────────

  /// Returns null on success. On success, [lastForgotPasswordMeta] holds
  /// account email / channel / masked destination from the API.
  Map<String, dynamic>? lastForgotPasswordMeta;

  Future<String?> sendForgotPasswordOtp({
    String? email,
    String? identifier,
  }) async {
    _loading = true; _error = null; _lastErrorCode = null;
    lastForgotPasswordMeta = null;
    notifyListeners();
    final result = await ApiService.sendForgotPasswordOtp(
      email: email,
      identifier: identifier ?? email,
    );
    _loading = false;
    final data = result.data is Map ? result.data as Map<String, dynamic> : null;
    if (result.statusCode == 200) {
      lastForgotPasswordMeta = data;
      notifyListeners();
      return null;
    }
    _lastErrorCode = data?['error_code']?.toString();
    _error = data?['error'] as String? ?? result.errorMessage ?? 'Failed to send verification code';
    notifyListeners();
    return _error;
  }

  Future<Map<String, dynamic>?> verifyForgotPasswordOtp({
    required String email,
    required String otpCode,
  }) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.verifyForgotPasswordOtp(email: email, otpCode: otpCode);
    _loading = false;
    final data = result.data as Map<String, dynamic>? ?? {};
    if (result.statusCode == 200 && data['verified'] == true) {
      notifyListeners();
      return null;
    }
    _error = data['error'] as String? ?? result.errorMessage ?? 'Verification failed';
    notifyListeners();
    return data;
  }

  Future<Map<String, dynamic>?> resendForgotPasswordOtp({required String email}) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.resendForgotPasswordOtp(email: email);
    _loading = false;
    final data = result.data as Map<String, dynamic>? ?? {};
    if (result.statusCode == 200) { notifyListeners(); return null; }
    _lastErrorCode = data['error_code']?.toString();
    _error = data['error'] as String? ?? result.errorMessage ?? 'Failed to resend code';
    notifyListeners();
    return data;
  }

  Future<String?> resetPasswordAfterOtp({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _loading = true; _error = null; _lastErrorCode = null; notifyListeners();
    final result = await ApiService.resetPasswordAfterOtp(
      email: email,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    _loading = false;
    final data = result.data is Map ? result.data as Map<String, dynamic> : null;
    if (result.statusCode == 200) { notifyListeners(); return null; }
    _error = data?['error'] as String? ?? result.errorMessage ?? 'Failed to reset password';
    notifyListeners();
    return _error;
  }

  // ── Refresh user from server ─────────────────────────────────────────
  Future<void> refreshUser() async {
    final result = await ApiService.getMe();
    if (result.isSuccess && result.data is Map) {
      final userMap = result.data as Map<String, dynamic>;
      _user = User.fromJson(userMap);
      final p = await SharedPreferences.getInstance();
      await p.setString('user_data', jsonEncode({'user': userMap}));
      notifyListeners();
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────
  Future<void> logout({bool notify = true}) async {
    await ApiService.clearToken();
    _user = null;
    if (notify) notifyListeners();
  }
}
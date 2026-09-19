import '../services/api_service.dart';

/// Runtime flag for profile phone OTP. Default matches the server default
/// (off). [refreshPhoneBindFlags] loads Admin Controls from the API.
bool kRequirePhoneBindOtp = false;

/// Runtime flag for customer phone registration. Default is true.
/// [refreshPhoneBindFlags] loads Admin Controls from the API.
bool kAllowPhoneRegistration = true;

Future<void> refreshPhoneBindFlags() async {
  try {
    final res = await ApiService.getFeatureFlags();
    final data = res.data;
    if (data is Map) {
      kRequirePhoneBindOtp = data['phone_bind_otp'] == true;
      if (data.containsKey('phone_registration')) {
        kAllowPhoneRegistration = data['phone_registration'] != false;
      }
    }
  } catch (_) {}
}

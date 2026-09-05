import '../services/api_service.dart';

/// Runtime flag for profile phone OTP. Default matches the server default
/// (off). [refreshPhoneBindFlags] loads Admin Controls from the API.
bool kRequirePhoneBindOtp = false;

Future<void> refreshPhoneBindFlags() async {
  try {
    final res = await ApiService.getFeatureFlags();
    final data = res.data;
    if (data is Map) {
      kRequirePhoneBindOtp = data['phone_bind_otp'] == true;
    }
  } catch (_) {}
}

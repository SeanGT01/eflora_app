class User {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final bool needsPhone;
  final String? avatarUrl;        // Cloudinary URL
  final String? avatarPublicId;    // Cloudinary public ID
  final String? birthday;
  final String? gender;
  final bool isPhoneLogin;

  const User({
    required this.id, required this.fullName, required this.email,
    required this.role, this.phone, this.needsPhone = false, this.isPhoneLogin = false,
    this.avatarUrl, this.avatarPublicId, this.birthday, this.gender,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? 0,
    fullName: j['full_name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'customer',
    phone: j['phone'],
    needsPhone: j['needs_phone'] == true ||
        ((j['phone'] == null || (j['phone'] as String?)?.trim().isEmpty == true) &&
            (j['email'] ?? '').toString().contains('@') &&
            j['is_phone_login'] != true),
    isPhoneLogin: j['is_phone_login'] == true,
    avatarUrl: j['avatar_url'],               // Full Cloudinary URL from API
    avatarPublicId: j['avatar_public_id'],    // Public ID for transformations
    birthday: j['birthday'],
    gender: j['gender'],
  );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }
}

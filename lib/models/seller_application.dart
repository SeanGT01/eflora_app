class SellerApplication {
  final int id;
  final int userId;
  final String storeName;
  final String? storeDescription;
  final String? storeLogoUrl;
  final String? storeLogoPublicId;
  final String? governmentIdUrl;
  final String? governmentIdPublicId;
  final String status; // pending, approved, rejected
  final String? adminNotes;
  final Map<String, dynamic>? rejectionDetails;
  final String? submittedAt;
  final String? reviewedAt;
  final String? reviewerName;

  const SellerApplication({
    required this.id,
    required this.userId,
    required this.storeName,
    this.storeDescription,
    this.storeLogoUrl,
    this.storeLogoPublicId,
    this.governmentIdUrl,
    this.governmentIdPublicId,
    required this.status,
    this.adminNotes,
    this.rejectionDetails,
    this.submittedAt,
    this.reviewedAt,
    this.reviewerName,
  });

  factory SellerApplication.fromJson(Map<String, dynamic> j) => SellerApplication(
    id: j['id'] ?? 0,
    userId: j['user_id'] ?? 0,
    storeName: j['store_name'] ?? '',
    storeDescription: j['store_description'],
    storeLogoUrl: j['store_logo_url'],
    storeLogoPublicId: j['store_logo_public_id'],
    governmentIdUrl: j['government_id_url'],
    governmentIdPublicId: j['government_id_public_id'],
    status: j['status'] ?? 'pending',
    adminNotes: j['admin_notes'],
    rejectionDetails: j['rejection_details'] != null
        ? Map<String, dynamic>.from(j['rejection_details'])
        : null,
    submittedAt: j['submitted_at'],
    reviewedAt: j['reviewed_at'],
    reviewerName: j['reviewer_name'],
  );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  bool isFieldRejected(String field) {
    if (rejectionDetails == null) return false;
    final detail = rejectionDetails![field];
    if (detail is Map) return detail['rejected'] == true;
    return false;
  }

  String? getRejectionReason(String field) {
    if (rejectionDetails == null) return null;
    final detail = rejectionDetails![field];
    if (detail is Map) return detail['reason'] as String?;
    return null;
  }

  List<String> get rejectedFields {
    if (rejectionDetails == null) return [];
    return rejectionDetails!.entries
        .where((e) => e.value is Map && e.value['rejected'] == true)
        .map((e) => e.key)
        .toList();
  }
}

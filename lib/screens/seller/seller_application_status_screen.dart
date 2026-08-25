import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../services/api_service.dart';
import '../../models/seller_application.dart';
import 'seller_application_screen.dart';

class SellerApplicationStatusScreen extends StatefulWidget {
  const SellerApplicationStatusScreen({super.key});

  @override
  State<SellerApplicationStatusScreen> createState() => _SellerApplicationStatusScreenState();
}

class _SellerApplicationStatusScreenState extends State<SellerApplicationStatusScreen> {
  SellerApplication? _application;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    setState(() => _loading = true);
    final result = await ApiService.getSellerApplication();
    if (result.isSuccess && result.data is Map) {
      final appData = (result.data as Map)['application'];
      setState(() {
        _application = appData != null ? SellerApplication.fromJson(Map<String, dynamic>.from(appData)) : null;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateToApplication() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerApplicationScreen(
          existingApplication: _application?.isRejected == true ? _application : null,
        ),
      ),
    );
    if (submitted == true) _loadApplication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Seller Application')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose))
          : RefreshIndicator(
              color: AppColors.deepRose,
              onRefresh: _loadApplication,
              child: _application == null ? _buildNoApplication() : _buildApplicationDetails(),
            ),
    );
  }

  Widget _buildNoApplication() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, size: 40, color: AppColors.deepRose),
              ),
              const SizedBox(height: 20),
              Text(
                'Start Selling on E-FLORA',
                style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.charcoal),
              ),
              const SizedBox(height: 8),
              Text(
                'Apply to become a seller and start your flower business with us.',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              RoseButton(
                label: 'Apply Now',
                icon: Icons.send_outlined,
                onPressed: _navigateToApplication,
                width: double.infinity,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationDetails() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Status card
        _buildStatusCard(),
        const SizedBox(height: 20),

        // Application details
        _buildDetailCard(),
        const SizedBox(height: 20),

        // Documents
        _buildDocumentsCard(),
        const SizedBox(height: 20),

        // Rejection details (if rejected)
        if (_application!.isRejected) ...[
          _buildRejectionCard(),
          const SizedBox(height: 20),
          RoseButton(
            label: 'Update & Resubmit',
            icon: Icons.edit_outlined,
            onPressed: _navigateToApplication,
            width: double.infinity,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    String statusDesc;

    switch (_application!.status) {
      case 'approved':
        statusColor = AppColors.sage;
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'Approved';
        statusDesc = 'Your application has been approved! You are now a seller.';
        break;
      case 'rejected':
        statusColor = const Color(0xFFc0392b);
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Rejected';
        statusDesc = 'Your application was rejected. Please review the details and resubmit.';
        break;
      default:
        statusColor = const Color(0xFFf0b429);
        statusIcon = Icons.schedule_outlined;
        statusLabel = 'Pending Review';
        statusDesc = 'Your application is being reviewed by our admin team.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(statusIcon, color: statusColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusLabel, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: statusColor)),
            const SizedBox(height: 4),
            Text(statusDesc, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Application Details', style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
        const Divider(height: 24, color: AppColors.border),
        _detailRow('Store Name', _application!.storeName),
        const SizedBox(height: 12),
        _detailRow('Description', _application!.storeDescription ?? 'N/A'),
        const SizedBox(height: 12),
        _detailRow('Submitted', _formatDate(_application!.submittedAt)),
        if (_application!.reviewedAt != null) ...[
          const SizedBox(height: 12),
          _detailRow('Reviewed', _formatDate(_application!.reviewedAt)),
        ],
        if (_application!.reviewerName != null) ...[
          const SizedBox(height: 12),
          _detailRow('Reviewed By', _application!.reviewerName!),
        ],
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 100,
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ),
      Expanded(
        child: Text(value, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.charcoal)),
      ),
    ]);
  }

  Widget _buildDocumentsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Submitted Documents', style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
        const Divider(height: 24, color: AppColors.border),
        _documentThumbnail('Store Logo', _application!.storeLogoUrl, _application!.isFieldRejected('store_logo')),
        const SizedBox(height: 12),
        _documentThumbnail('Government ID', _application!.governmentIdUrl, _application!.isFieldRejected('government_id')),
      ]),
    );
  }

  Widget _documentThumbnail(String label, String? url, bool rejected) {
    return Row(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rejected ? const Color(0xFFc0392b) : AppColors.border),
          color: AppColors.cream,
        ),
        child: url != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
              )
            : const Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.charcoal)),
          if (rejected)
            Text('Rejected - needs update', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFc0392b))),
        ]),
      ),
      if (rejected)
        const Icon(Icons.warning_amber_outlined, size: 18, color: Color(0xFFc0392b)),
    ]);
  }

  Widget _buildRejectionCard() {
    final details = _application!.rejectionDetails;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFc0392b).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFc0392b).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_outlined, size: 20, color: Color(0xFFc0392b)),
          const SizedBox(width: 8),
          Text('Rejection Details', style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFFc0392b))),
        ]),
        if (_application!.adminNotes != null && _application!.adminNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _application!.adminNotes!,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.charcoal),
          ),
        ],
        if (details != null) ...[
          const SizedBox(height: 12),
          ...details.entries.where((e) => e.value is Map && e.value['rejected'] == true).map((e) {
            final fieldLabel = e.key.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
            final reason = e.value['reason'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.close, size: 16, color: Color(0xFFc0392b)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.charcoal),
                      children: [
                        TextSpan(text: '$fieldLabel: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: reason),
                      ],
                    ),
                  ),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

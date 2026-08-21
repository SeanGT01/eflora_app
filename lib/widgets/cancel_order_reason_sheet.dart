import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CancelReasonOption {
  final String code;
  final String label;
  const CancelReasonOption(this.code, this.label);
}

/// Matches backend `CUSTOMER_CANCEL_REASONS`.
const List<CancelReasonOption> kCustomerCancelReasons = [
  CancelReasonOption('changed_mind', 'I changed my mind'),
  CancelReasonOption('ordered_by_mistake', 'Ordered by mistake'),
  CancelReasonOption('wrong_details', 'Wrong item / address details'),
  CancelReasonOption('delivery_time', 'Delivery time no longer works'),
  CancelReasonOption('found_alternative', 'Found another store / product'),
  CancelReasonOption('payment_issue', 'Payment / checkout issue'),
  CancelReasonOption('other', 'Other'),
];

class CancelOrderReasonResult {
  final String reasonCode;
  final String? reason;
  const CancelOrderReasonResult({required this.reasonCode, this.reason});
}

/// Bottom sheet: pick a cancel reason chip (+ required details for Other).
Future<CancelOrderReasonResult?> showCancelOrderReasonSheet(BuildContext context) {
  return showModalBottomSheet<CancelOrderReasonResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CancelOrderReasonSheet(),
  );
}

class _CancelOrderReasonSheet extends StatefulWidget {
  const _CancelOrderReasonSheet();

  @override
  State<_CancelOrderReasonSheet> createState() => _CancelOrderReasonSheetState();
}

class _CancelOrderReasonSheetState extends State<_CancelOrderReasonSheet> {
  String? _code;
  final _detailsCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code;
    if (code == null) {
      setState(() => _error = 'Please select a cancellation reason.');
      return;
    }
    final details = _detailsCtrl.text.trim();
    if (code == 'other' && details.length < 5) {
      setState(() =>
          _error = 'Please tell us specifically why you are cancelling (at least 5 characters).');
      return;
    }
    Navigator.pop(
      context,
      CancelOrderReasonResult(
        reasonCode: code,
        reason: details.isEmpty ? null : details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFBF7F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cancel order',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please select a reason for cancelling. This helps us improve your experience.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...kCustomerCancelReasons.map((r) {
                        final selected = _code == r.code;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _code = r.code;
                              _error = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0x24C24E68)
                                    : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFD878A0)
                                      : const Color(0x8CE6AAC3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                r.label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? const Color(0xFF9B1C1C)
                                      : AppColors.charcoal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_code == 'other') ...[
                        const SizedBox(height: 14),
                        Text(
                          'Tell us specifically why',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _detailsCtrl,
                          maxLength: 500,
                          maxLines: 3,
                          onChanged: (_) => setState(() => _error = null),
                          style: GoogleFonts.dmSans(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Please share a few details…',
                            hintStyle: GoogleFonts.dmSans(
                                fontSize: 13, color: AppColors.muted),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.deepRose, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF9B1C1C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppColors.charcoal,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text('Keep order',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: const Color(0xFF9B1C1C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(
                          'Cancel order',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

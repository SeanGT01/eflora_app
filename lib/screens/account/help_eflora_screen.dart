import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class HelpEfloraScreen extends StatelessWidget {
  const HelpEfloraScreen({super.key});

  static const _supportEmail = 'support@eflora.ph';
  static const _site = 'https://eflora-system-production.up.railway.app';

  Future<void> _mail() async {
    final uri = Uri.parse('mailto:$_supportEmail');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openSite() async {
    final uri = Uri.parse(_site);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Help E-FLORA'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'We’re here to help you order flowers from local Laguna shops.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            const _HelpCard(
              title: 'How to order',
              body:
                  'Browse shops in your area, add items to your cart, choose a delivery address, then pay with GCash or cash on delivery. Track the order from My Orders.',
            ),
            const _HelpCard(
              title: 'Delivery',
              body:
                  'E-FLORA delivers through partner shops and riders in their selected municipalities. Confirm your pin and contact number so the rider can reach you.',
            ),
            const _HelpCard(
              title: 'Verification SMS',
              body:
                  'Account and phone checks use a 6-digit SMS code. If the text is delayed, wait a minute and tap resend. Make sure your number is a valid Philippine mobile.',
            ),
            const _HelpCard(
              title: 'Payments & cancellations',
              body:
                  'GCash orders need a payment proof the seller can verify. COD is paid on delivery. Cancel from My Orders while the shop has not finished preparing, when the app allows it.',
            ),
            const SizedBox(height: 8),
            GlassCard(
              tinted: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email us anytime. We read messages in Philippine time.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline, color: AppColors.roseCta),
                    title: const Text(_supportEmail),
                    onTap: _mail,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language, color: AppColors.roseCta),
                    title: const Text('Open the E-FLORA website'),
                    onTap: _openSite,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class AboutEfloraScreen extends StatelessWidget {
  const AboutEfloraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('About E-FLORA'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              tinted: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-FLORA',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Blooming with Technology',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.dustyRose,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'E-FLORA is a Laguna flower marketplace that connects you with nearby florists. Order arrangements, add-ons, and gifts, then have them delivered by the shop’s riders.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.5,
                      height: 1.55,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What we do',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shops set their own products, delivery areas, and schedules. You shop in the app or on the website, pay with GCash or cash on delivery, and follow the order until it arrives.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Made with care in the Philippines',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'E-FLORA is built for local florists and customers in Laguna. We keep your delivery details private and use them only to fulfill your orders.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '© 2026 E-FLORA. All rights reserved.',
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

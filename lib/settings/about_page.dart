import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'settings_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubPageHeader(title: "About Sa'af"),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: Column(
                  children: [
                    const _GlowingLogo(),
                    const SizedBox(height: 8),

                    // App name
                    const Text(
                      "Sa'af",
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Version pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F0E6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Version 1.0',
                        style: TextStyle(
                          color: AppColors.healthyGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Description card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                      decoration: _cardDecoration(26),
                      child: const Text(
                        "Sa'af uses AI to analyze date palm leaf images, "
                        'identify possible diseases, and visually explain '
                        'its predictions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Feature cards
                    const Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.center_focus_weak_rounded,
                            title: 'Detect',
                            subtitle: 'diseases',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.auto_awesome_outlined,
                            title: 'AI',
                            subtitle: 'explanations',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.history_rounded,
                            title: 'Track',
                            subtitle: 'your palms',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),

                    // Footer
                    const Text(
                      "© 2026 Sa'af · Made for date palm care",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SettingsSubPageNavBar(),
    );
  }
}

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFEDEFEA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );

/// Logo inside a light circle with a soft green glow around it.
class _GlowingLogo extends StatelessWidget {
  const _GlowingLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Very faint outer ring
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.lime.withValues(alpha: 0.10),
                  AppColors.lime.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Logo circle
          Container(
            width: 172,
            height: 172,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6EE),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: OverflowBox(
                maxWidth: 212,
                maxHeight: 212,
                child: Image.asset(
                  'assets/images/logo_color.png',
                  width: 212,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.eco,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small white card with an icon, a bold title and a grey subtitle.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      decoration: _cardDecoration(24),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
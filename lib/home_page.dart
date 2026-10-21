import 'package:flutter/material.dart';

import 'History.dart';
import 'scan_page.dart';
import 'settings/settings_page.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HomeHeader(
              greeting: 'Hi, $_greeting',
              onSettingsTap: () => _open(context, const SettingsPage()),
              onBellTap: () => _showMessage(context, "You're all caught up."),
              onDiagnoseTap: () => _open(context, const ScanPage()),
            ),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                child: const HomeScansSection(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(current: NavTab.home),
    );
  }
}

// ============================================================
// HEADER: palm photo, buttons, greeting, Diagnose now
// ============================================================

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.onSettingsTap,
    required this.onBellTap,
    required this.onDiagnoseTap,
  });

  final String greeting;
  final VoidCallback onSettingsTap;
  final VoidCallback onBellTap;
  final VoidCallback onDiagnoseTap;

  Widget _glassButton(IconData icon, VoidCallback onTap, {bool dot = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          if (dot)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/onboarding_1.jpg', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF173F2C).withValues(alpha: 0.15),
                  const Color(0xFF173F2C).withValues(alpha: 0.35),
                  const Color(0xFF0F2A1D).withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _glassButton(Icons.settings_outlined, onSettingsTap),
                      const Spacer(),
                      _glassButton(Icons.notifications_none_rounded, onBellTap,
                          dot: true),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 15, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 4),
                      Text(
                        'My Palm Farm',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Is your palm\nhealthy today?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onDiagnoseTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Diagnose now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RECENT DIAGNOSES: real data from Firestore (same source as History)
// ============================================================

class HomeScansSection extends StatefulWidget {
  const HomeScansSection({super.key});

  @override
  State<HomeScansSection> createState() => _HomeScansSectionState();
}

class _HomeScansSectionState extends State<HomeScansSection> {
  late final Stream<List<ScanRecord>> _stream =
      HistoryRepository().watchScans();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScanRecord>>(
      stream: _stream,
      builder: (context, snapshot) {
        final scans = snapshot.data ?? const <ScanRecord>[];

        Widget list;
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          list = const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          list = const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Could not load your scans.',
                style: TextStyle(color: AppColors.mutedText)),
          );
        } else if (scans.isEmpty) {
          list = const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No scans yet. Tap "Diagnose now" to start.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
          );
        } else {
          list = Column(
            children: [
              for (final r in scans.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RecentScanCard(
                    record: r,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ScanDetailsScreen(record: r),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent diagnoses',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const HistoryScreen()),
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            list,
          ],
        );
      },
    );
  }
}

// ============================================================
// SHARED PIECES (also used later by History)
// ============================================================

/// "Today, 8:02 AM" / "Yesterday, 2:15 PM" / "22 August"
String formatScanDate(DateTime d) {
  final now = DateTime.now();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final time = '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Yesterday, $time';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

/// "• Diseased" / "• Healthy" pill
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.isHealthy});
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? AppColors.healthyGreen : AppColors.diseased;
    final bg = isHealthy ? AppColors.softGreen : const Color(0xFFFBE7DD);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isHealthy ? 'Healthy' : 'Diseased',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded confidence bar (orange for diseased, green for healthy)
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    super.key,
    required this.percent,
    required this.isHealthy,
  });
  final int percent;
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final colors = isHealthy
        ? const [Color(0xFF63B97F), Color(0xFF2F7D4E)]
        : const [Color(0xFFE8834F), Color(0xFFC8481F)];
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.inputBorder,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: (percent / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// One scan card: photo, name, status, date, confidence bar.
class RecentScanCard extends StatelessWidget {
  const RecentScanCard({
    super.key,
    required this.record,
    required this.onTap,
    this.trailing,
  });

  final ScanRecord record;
  final VoidCallback onTap;
  final Widget? trailing; // e.g. delete button in History

  @override
  Widget build(BuildContext context) {
    final percent = record.confidence.round().clamp(0, 100);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEFEA)),
          ),
          child: Row(
            children: [
              ScanImage(
                url: record.imageUrl,
                isHealthy: record.isHealthy,
                width: 54,
                height: 54,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(isHealthy: record.isHealthy),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 4),
                        Text(
                          formatScanDate(record.date),
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ConfidenceBar(
                            percent: percent,
                            isHealthy: record.isHealthy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
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
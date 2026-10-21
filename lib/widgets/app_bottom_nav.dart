import 'package:flutter/material.dart';

import '../History.dart';
import '../chatbot.dart';
import '../scan_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_colors.dart';

enum NavTab { home, chatbot, scan, history, settings }

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.current,
    this.onHomeTap,
    this.onChatbotTap,
    this.onFrameTap,
    this.onHistoryTap,
    this.onSettingsTap,
  });

  final NavTab current;
  // Optional: if a page does not pass its own action, the default
  // navigation below (_goTo) is used for that tab.
  final VoidCallback? onHomeTap;
  final VoidCallback? onChatbotTap;
  final VoidCallback? onFrameTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSettingsTap;

  /// Shared navigation for every page: go back to Home (the first page),
  /// then open the chosen tab on top of it. Back from any tab returns Home.
  void _goTo(BuildContext context, NavTab tab) {
    if (tab == current) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    final Widget? page = switch (tab) {
      NavTab.home => null,
      NavTab.chatbot => const ChatbotScreen(),
      NavTab.scan => const ScanPage(),
      NavTab.history => const HistoryScreen(),
      NavTab.settings => const SettingsPage(),
    };
    if (page != null) {
      navigator.push(MaterialPageRoute<void>(builder: (_) => page));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: current == NavTab.home,
                  onTap: onHomeTap ?? (() => _goTo(context, NavTab.home)),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_outline_rounded,
                  label: 'Chatbot',
                  isSelected: current == NavTab.chatbot,
                  onTap:
                      onChatbotTap ?? (() => _goTo(context, NavTab.chatbot)),
                ),
              ),
              Expanded(
                child: _ScanItem(
                  isSelected: current == NavTab.scan,
                  onTap: onFrameTap ?? (() => _goTo(context, NavTab.scan)),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history_rounded,
                  label: 'History',
                  isSelected: current == NavTab.history,
                  onTap:
                      onHistoryTap ?? (() => _goTo(context, NavTab.history)),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_outlined,
                  label: 'Settings',
                  isSelected: current == NavTab.settings,
                  onTap: onSettingsTap ??
                      (() => _goTo(context, NavTab.settings)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One tab: icon in a lime pill when selected, label under it.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  static const Color _inactive = Color(0xFF8A938E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.lime : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? AppColors.primary : _inactive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? AppColors.primary : _inactive,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Middle Scan button: dark green circle with the palm logo.
class _ScanItem extends StatelessWidget {
  const _ScanItem({required this.onTap, this.isSelected = false});

  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
                        child: ClipOval(
              child: Transform.translate(
                // The star is a bit left/down inside the image, so move it back.
                offset: const Offset(1.4, -2.5),
                child: Transform.scale(
                  scale: 1.45,
                  child: Image.asset('assets/images/logo_light.png'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
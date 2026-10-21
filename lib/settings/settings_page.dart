import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../create_account.dart';
import '../main.dart' show LoginScreen;
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'about_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'help_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AuthService.errorMessage(e)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------- Log out ----------------
  Future<void> _logOut(BuildContext context, bool isGuest) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message: isGuest
          ? 'You are using a guest account. Your scans and chats will be deleted when you log out.'
          : "Are you sure you want to log out of your Sa'af account?",
      confirmLabel: 'Log out',
      danger: isGuest,
    );
    if (!confirmed || !context.mounted) return;

    try {
      // A guest can't log back in, so remove the guest account and its data.
      if (isGuest) {
        await AuthService().deleteAccount();
      } else {
        await AuthService().logOut();
      }
      if (!context.mounted) return;
      _goToLogin(context);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  // ---------------- Delete account ----------------
  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete account?',
      message:
          'This will permanently delete your account and all your scan data.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await AuthService().deleteAccount();
      if (!context.mounted) return;
      _goToLogin(context);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  // ---------------- Guest: sign up ----------------
  Future<void> _guestSignUp(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.person_add_alt_1_outlined,
      title: 'Create an account?',
      message:
          'Your guest scans and chats will be deleted. Scans you make after signing up will be saved to your new account.',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await AuthService().deleteAccount();
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const CreateAccountScreen()),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: StreamBuilder<User?>(
        stream: AuthService().userChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
          final isGuest = user?.isAnonymous ?? false;
          final name = (user?.displayName ?? '').trim();

          return SingleChildScrollView(
            child: Column(
              children: [
                _SettingsHeader(
                  name: isGuest ? 'Guest' : (name.isEmpty ? 'User' : name),
                  subtitle: isGuest
                      ? 'Create an account to use all features'
                      : (user?.email ?? ''),
                  isGuest: isGuest,
                  onEdit: () => _open(context, const EditProfilePage()),
                  onSignUp: () => _guestSignUp(context),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.pageBg,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isGuest) ...[
                          const _SectionLabel('ACCOUNT'),
                          _SettingsGroup(children: [
                            SettingsTile(
                              icon: Icons.person_outline,
                              label: 'Edit Profile',
                              onTap: () =>
                                  _open(context, const EditProfilePage()),
                            ),
                            SettingsTile(
                              icon: Icons.lock_outline,
                              label: 'Change Password',
                              onTap: () =>
                                  _open(context, const ChangePasswordPage()),
                            ),
                          ]),
                          const SizedBox(height: 22),
                        ],
                        const _SectionLabel('SUPPORT'),
                        _SettingsGroup(children: [
                          SettingsTile(
                            icon: Icons.help_outline,
                            label: 'Help',
                            onTap: () => _open(context, const HelpPage()),
                          ),
                          SettingsTile(
                            icon: Icons.info_outline,
                            label: "About Sa'af",
                            onTap: () => _open(context, const AboutPage()),
                          ),
                        ]),
                        const SizedBox(height: 22),
                        const _SectionLabel('SESSION'),
                        _SettingsGroup(children: [
                          SettingsTile(
                            icon: Icons.logout_rounded,
                            label: 'Log Out',
                            onTap: () => _logOut(context, isGuest),
                          ),
                          SettingsTile(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete Account',
                            danger: true,
                            onTap: () => _deleteAccount(context),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar:
          const AppBottomNavigationBar(current: NavTab.settings),
    );
  }
}

// ============================================================
// HEADER: palm photo, title, profile card
// ============================================================

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.name,
    required this.subtitle,
    required this.isGuest,
    required this.onEdit,
    required this.onSignUp,
  });

  final String name;
  final String subtitle;
  final bool isGuest;
  final VoidCallback onEdit;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/onboarding_3.png', fit: BoxFit.cover),
          Container(color: const Color(0xFF0F2A1D).withValues(alpha: 0.35)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Glass profile card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isGuest)
                          GestureDetector(
                            onTap: onSignUp,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 19),
                            ),
                          ),
                      ],
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
// LIST PIECES
// ============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// White rounded card that holds tiles with dividers between them.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDEFEA)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: Color(0xFFE9ECE6),
              ),
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFFCE6E3) : AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: danger ? AppColors.danger : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!danger)
              const Icon(Icons.chevron_right,
                  color: AppColors.mutedText, size: 22),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

/// Opens the Login page and removes all other pages,
/// so the back button can't return to the app.
void _goToLogin(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/// Popup asking the user to confirm an action.
/// Returns true if the user taps the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.help_outline,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xFF173F2C).withValues(alpha: 0.45),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      danger ? const Color(0xFFFCE6E3) : AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: danger ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF1EC),
                          foregroundColor: AppColors.textDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              danger ? AppColors.danger : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
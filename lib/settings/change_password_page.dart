import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'settings_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _showSuccess = false;

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  int _strength = 0; // 0..4

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------------- Password strength (same rules as Create account) ----
  int _passwordStrength(String p) {
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score == 0 ? 1 : score;
  }

  String get _strengthLabel => const [
        '',
        'Weak password',
        'Fair password',
        'Strong password',
        'Very strong password',
      ][_strength];

  Color get _strengthColor => switch (_strength) {
        1 => AppColors.danger,
        2 => AppColors.diseased,
        _ => AppColors.healthyGreen,
      };

  bool get _passwordsMatch =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text == _newController.text;

  // ---------------- Save ----------------
  Future<void> _saveChanges() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;

      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() {
        _strength = 0;
        _showSuccess = true;
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final wrongPassword =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      _showError(wrongPassword
          ? 'Current password is incorrect.'
          : AuthService.errorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------- Validation ----------------
  String? _validateCurrent(String? v) =>
      (v == null || v.isEmpty) ? 'Current password is required' : null;

  String? _validateNew(String? v) {
    if (v == null || v.isEmpty) return 'New password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v == _currentController.text) return 'New password must be different';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _newController.text) return 'Passwords do not match';
    return null;
  }

  // ---------------- UI ----------------
  Widget _strengthBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color:
                      i < _strength ? _strengthColor : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 4),
          SizedBox(
            width: 130,
            child: Text(
              _strengthLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _strengthColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Change Password'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: !_showSuccess
                            ? const SizedBox.shrink()
                            : const Padding(
                                padding: EdgeInsets.only(bottom: 22),
                                child: SuccessBanner(
                                  message: 'Password changed successfully',
                                ),
                              ),
                      ),
                      const Text(
                        'Your new password must be at least\n8 characters long.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),

                      SettingsTextField(
                        label: 'Current password',
                        controller: _currentController,
                        icon: Icons.lock_outline,
                        hint: '••••••••',
                        obscureText: _hideCurrent,
                        onToggleObscure: () =>
                            setState(() => _hideCurrent = !_hideCurrent),
                        validator: _validateCurrent,
                      ),
                      const SizedBox(height: 18),

                      SettingsTextField(
                        label: 'New password',
                        controller: _newController,
                        icon: Icons.lock_outline,
                        hint: '••••••••',
                        obscureText: _hideNew,
                        onToggleObscure: () =>
                            setState(() => _hideNew = !_hideNew),
                        onChanged: (v) =>
                            setState(() => _strength = _passwordStrength(v)),
                        validator: _validateNew,
                      ),
                      if (_strength > 0) _strengthBar(),
                      const SizedBox(height: 18),

                      SettingsTextField(
                        label: 'Confirm new password',
                        controller: _confirmController,
                        icon: Icons.lock_outline,
                        hint: '••••••••',
                        obscureText: _hideConfirm,
                        onChanged: (_) => setState(() {}),
                        validator: _validateConfirm,
                        // Green check when both passwords match
                        suffix: _passwordsMatch
                            ? const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: Icon(Icons.check_circle,
                                    color: AppColors.healthyGreen, size: 22),
                              )
                            : IconButton(
                                onPressed: () => setState(
                                    () => _hideConfirm = !_hideConfirm),
                                icon: Icon(
                                  _hideConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.mutedText,
                                  size: 21,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SaveButton(
                loading: _isSaving,
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SettingsSubPageNavBar(),
    );
  }
}
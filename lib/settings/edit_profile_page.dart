import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'settings_widgets.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  bool _isSaving = false;

  // Message shown in the green box (null = hidden)
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    // Shows the red error under the field if the name is empty
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    if (newName == (_auth.currentUser?.displayName ?? '')) {
      _showError('No changes to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _auth.updateName(newName);
      if (!mounted) return;
      setState(() => _successMessage = 'Profile updated successfully');

      // Hide the message after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubPageHeader(title: 'Edit Profile'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_successMessage != null) ...[
                        SuccessBanner(message: _successMessage!),
                        const SizedBox(height: 20),
                      ],

                      // Avatar
                      Center(
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: AppColors.softGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lime.withValues(alpha: 0.30),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SettingsTextField(
                        label: 'Full name',
                        controller: _nameController,
                        validator: _validateName,
                        icon: Icons.person_outline_rounded,
                        hint: 'Your name',
                      ),
                      const SizedBox(height: 20),

                      // Email can't be changed
                      SettingsTextField(
                        label: 'Email',
                        controller: _emailController,
                        icon: Icons.mail_outline_rounded,
                        readOnly: true,
                        suffix: const Icon(Icons.lock_outline_rounded,
                            size: 20, color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 40),

                      SaveButton(
                        label: 'Save Changes',
                        loading: _isSaving,
                        onPressed: _saveChanges,
                      ),
                    ],
                  ),
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
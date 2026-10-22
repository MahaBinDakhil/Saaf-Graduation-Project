import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

/// Header for inner settings pages: round back button and centered title.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: AppColors.textDark, size: 26),
                ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label with a rounded white text field under it.
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.icon,
    this.hint,
    this.readOnly = false,
    this.onToggleObscure,
    this.onChanged,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? icon;
  final String? hint;
  final bool readOnly;
  final VoidCallback? onToggleObscure; // shows the eye button
  final ValueChanged<String>? onChanged;
  final Widget? suffix; // e.g. a green check

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(27),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffixIcon = suffix;
    if (onToggleObscure != null) {
      suffixIcon = IconButton(
        onPressed: onToggleObscure,
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.mutedText,
          size: 21,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          onChanged: onChanged,
          cursorColor: AppColors.primary,
          style: TextStyle(
            color: readOnly ? AppColors.mutedText : AppColors.textDark,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.mutedText, fontSize: 15),
            filled: true,
            // Light red background when the field has an error
            fillColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.error)
                  ? const Color(0xFFFFF5F3)
                  : Colors.white,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: icon == null ? 20 : 0,
              vertical: 17,
            ),
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 18, right: 10),
                    child: Icon(icon, size: 21),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            prefixIconColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.error)
                  ? AppColors.danger
                  : (states.contains(WidgetState.focused)
                      ? AppColors.primary
                      : AppColors.mutedText),
            ),
            suffixIcon: suffixIcon,
            border: _border(AppColors.inputBorder),
            enabledBorder: _border(AppColors.inputBorder),
            focusedBorder: _border(AppColors.primary, 1.5),
            errorBorder: _border(AppColors.danger, 1.5),
            focusedErrorBorder: _border(AppColors.danger, 1.5),
            errorStyle: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width dark green pill button used to save forms.
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.onPressed,
    this.label = 'Save Changes',
    this.loading = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

/// Light green message box shown after a successful save.
class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCDE5D3)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.healthyGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.healthyGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar for pages opened from Settings.
class SettingsSubPageNavBar extends StatelessWidget {
  const SettingsSubPageNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBottomNavigationBar(
      current: NavTab.settings,
      // In a settings sub-page, the Settings tab goes back to Settings.
      onSettingsTap: () => Navigator.of(context).pop(),
    );
  }
}
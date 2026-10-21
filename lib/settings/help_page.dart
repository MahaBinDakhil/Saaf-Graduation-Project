import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'settings_widgets.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Help'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: const [
                  Text(
                    'How can we help?',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Quick guides for using Sa'af",
                    style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                  ),
                  SizedBox(height: 22),
                  HelpSection(
                    icon: Icons.photo_camera_outlined,
                    title: 'How to scan a date palm leaf',
                    steps: [
                      HelpStep(
                        title: 'Start a scan',
                        description:
                            'On the Home page, tap "Diagnose now", or tap Scan in the bottom bar.',
                      ),
                      HelpStep(
                        title: 'Choose a photo',
                        description:
                            'Take a new photo or pick one from your gallery. Make sure the leaf is clear and well lit.',
                      ),
                      HelpStep(
                        title: 'View the result',
                        description:
                            'Wait for the scan to finish to see if the leaf is healthy or diseased, and the predicted disease.',
                      ),
                      HelpStep(
                        title: 'See the explanation',
                        description:
                            'Tap "View XAI Explanation" to see a heatmap of the areas that influenced the prediction.',
                      ),
                    ],
                  ),
                  HelpSection(
                    icon: Icons.bar_chart_rounded,
                    title: 'Understanding your results',
                    steps: [
                      HelpStep(
                        title: 'Status',
                        description:
                            '"Healthy" means no disease was found. "Diseased" means the model found signs of a disease.',
                      ),
                      HelpStep(
                        title: 'Confidence',
                        description:
                            'The percentage shows how sure the model is. A higher number means a more certain result.',
                      ),
                      HelpStep(
                        title: 'Heatmap and Region',
                        description:
                            'Red areas and the red outline show where the AI looked. They are not confirmed disease spots.',
                      ),
                      HelpStep(
                        title: 'Ask a specialist',
                        description:
                            "Sa'af gives a preliminary result. Please confirm it with an agricultural specialist.",
                      ),
                    ],
                  ),
                  HelpSection(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Using the chatbot',
                    steps: [
                      HelpStep(
                        title: 'Open the chatbot',
                        description:
                            'Tap Chatbot in the bottom bar, or "Ask the Chatbot" from a scan result.',
                      ),
                      HelpStep(
                        title: 'Ask your question',
                        description:
                            'Ask about palm diseases, care tips and treatments, in English or Arabic.',
                      ),
                      HelpStep(
                        title: 'Previous chats',
                        description:
                            'Tap the ⋯ button at the top to open your previous chats.',
                      ),
                    ],
                  ),
                  HelpSection(
                    icon: Icons.person_outline,
                    title: 'Managing your account',
                    steps: [
                      HelpStep(
                        title: 'Edit your profile',
                        description: 'Go to Settings, then Edit Profile.',
                      ),
                      HelpStep(
                        title: 'Change your password',
                        description:
                            'Go to Settings, then Change Password. You need your current password.',
                      ),
                      HelpStep(
                        title: 'Delete your account',
                        description:
                            'Go to Settings, then Delete Account. This also deletes all your scans and chats.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SettingsSubPageNavBar(),
    );
  }
}

class HelpStep {
  const HelpStep({required this.title, required this.description});
  final String title;
  final String description;
}

/// White card that opens to show numbered steps.
class HelpSection extends StatefulWidget {
  const HelpSection({
    super.key,
    required this.icon,
    required this.title,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final List<HelpStep> steps;

  @override
  State<HelpSection> createState() => _HelpSectionState();
}

class _HelpSectionState extends State<HelpSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _open ? AppColors.primary : const Color(0xFFEDEFEA),
          width: _open ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _open ? AppColors.lime : AppColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Color(0xFFE9ECE6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                children: [
                  for (var i = 0; i < widget.steps.length; i++)
                    _StepItem(number: i + 1, step: widget.steps[i]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Numbered circle, step title, and description.
class _StepItem extends StatelessWidget {
  const _StepItem({required this.number, required this.step});

  final int number;
  final HelpStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chatbot.dart';
import 'scan_page.dart';
import 'services/model_service.dart';
import 'History.dart';
import 'settings/settings_widgets.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

class AnalysisResultScreen extends StatelessWidget {
  final File imageFile;
  final ScanResult result;

  const AnalysisResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  static const Color primaryGreen = Color(0xFF1F6B45);
  static const Color darkGreen = Color(0xFF17372A);
  static const Color backgroundColor = Color(0xFFF7F8F2);
  static const Color lightGreen = Color(0xFFEAF2E9);
  static const Color textGrey = Color(0xFF66756D);

  // Save scan to Firebase Storage and Firestore
  Future<void> _saveScan(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  String saveStage = 'Starting save';

  try {
    // 1. Check authentication
    saveStage = 'Checking user authentication';

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in before saving a scan.');
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving scan and uploading images...'),
      ),
    );

    // 2. Prepare Firestore document
    saveStage = 'Preparing Firestore document';

    final scans = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scans');

    final scanDoc = scans.doc();


    // 3. Generate XAI images if necessary
    ScanResult resultToSave = result;

    if (!result.isHealthy &&
        (result.heatmap == null || result.region == null)) {
      saveStage = 'Generating explanation images';

      resultToSave = await ModelService.explain(imageFile);
    }

           // 4. Convert the images to text (base64) so they can be saved
       //    inside the Firestore document (no Firebase Storage needed).
       saveStage = 'Preparing images';

       final imageUrl =
           'data:image/jpeg;base64,${base64Encode(await imageFile.readAsBytes())}';

       // Firestore documents are limited to 1 MB, so the explanation
       // images are only saved if they are small enough.
    String? toDataUrl(Uint8List? bytes) {
      if (bytes == null) return null;
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final small =
          decoded.width > 600 ? img.copyResize(decoded, width: 600) : decoded;
      return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(small, quality: 70))}';
    }

       final heatmapUrl = toDataUrl(resultToSave.heatmap);
       final regionUrl = toDataUrl(resultToSave.region);
    // 9. Save scan information to Firestore
    saveStage = 'Saving Firestore document';

    await scanDoc.set({
      // Required by the current Firestore security rules.
      'label': result.diseaseName,
      'confidence': result.confidence,
      'isHealthy': result.isHealthy,
      'createdAt': FieldValue.serverTimestamp(),

      // Fields used by History.dart.
      'diseaseId': result.diseaseId,
      'diseaseName': result.diseaseName,
      'status': result.isHealthy ? 'healthy' : 'diseased',
      'predictions': result.toFirestore()['predictions'],

      // Uploaded image URLs.
      'imageUrl': imageUrl,
      'heatmapUrl': heatmapUrl,
      'regionUrl': regionUrl,
    });


    // Keep the counters on the user document up to date.
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'totalScans': FieldValue.increment(1),
      (result.isHealthy ? 'healthyCount' : 'diseasedCount'):
          FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 10. Navigate to History after successful save.
    if (!context.mounted) return;

    messenger.hideCurrentSnackBar();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const HistoryScreen(),
      ),
    );
  } on FirebaseException catch (e) {
    debugPrint('Failed stage: $saveStage');
    debugPrint('Firebase error code: ${e.code}');
    debugPrint('Firebase error message: ${e.message}');

    if (!context.mounted) return;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          'Failed at: $saveStage\n'
          'Firebase error (${e.code}): ${e.message ?? "Unknown error"}',
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Failed stage: $saveStage');
    debugPrint('Save error: $e');
    debugPrintStack(stackTrace: stackTrace);

    if (!context.mounted) return;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          'Failed at: $saveStage\nError: $e',
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final isHealthy = result.isHealthy;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubPageHeader(title: 'Analysis Result'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- IMAGE ----------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        height: 230,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (result.heatmap != null)
                              Image.memory(result.heatmap!, fit: BoxFit.cover)
                            else
                              Image.file(imageFile, fit: BoxFit.cover),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome_outlined,
                                        size: 16, color: AppColors.lime),
                                    SizedBox(width: 8),
                                    Text(
                                      'Analyzed just now',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- PREDICTION CARD ----------
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isHealthy
                                      ? AppColors.softGreen
                                      : const Color(0xFFFBE7DD),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isHealthy
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.warning_amber_rounded,
                                  color: isHealthy
                                      ? AppColors.healthyGreen
                                      : AppColors.diseased,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    const _SmallLabel('PREDICTION'),
                                    const SizedBox(height: 2),
                                    Text(
                                      result.diseaseName,
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusPill(isHealthy: isHealthy),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                              color: AppColors.inputBorder, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Confidence
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SmallLabel('CONFIDENCE'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _ConfidenceCircle(
                                            confidence: result.confidence),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              result.confidenceText,
                                              style: const TextStyle(
                                                color: AppColors.textDark,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Severity
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SmallLabel('SEVERITY'),
                                    const SizedBox(height: 10),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _SeverityPill(isHealthy: isHealthy),
                                    ),
                                  ],
                                ),
                              ),
                              // Palm
                              const Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SmallLabel('PALM'),
                                    SizedBox(height: 12),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'New scan',
                                        style: TextStyle(
                                          color: AppColors.textDark,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (result.lowConfidence) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4DD),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'The model has low confidence in this prediction. '
                                'Try taking a clearer photo with better lighting.',
                                style: TextStyle(
                                  color: Color(0xFF8A5A14),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- ABOUT ----------
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: isHealthy
                                ? 'About this result'
                                : 'About this disease',
                            icon: Icons.info_outline_rounded,
                          ),
                          const SizedBox(height: 8),
                          _DiseaseInfo(
                            diseaseId: result.diseaseId,
                            builder: (d) {
                              final description =
                                  (d['description'] ?? '').toString();
                              return Text(
                                description.isNotEmpty
                                    ? description
                                    : isHealthy
                                        ? 'The model classified this image as a healthy date palm leaf. Continue monitoring the palm and scan it again if you notice any changes.'
                                        : 'The AI model identified ${result.diseaseName} in the submitted image. Review the palm carefully and seek expert assessment to confirm the diagnosis.',
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 15,
                                  height: 1.55,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Model predictions',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (result.predictions.isEmpty)
                            const Text(
                              'No additional predictions available.',
                              style: TextStyle(
                                  color: AppColors.mutedText, fontSize: 14),
                            )
                          else
                            for (var i = 0;
                                i < result.predictions.take(3).length;
                                i++)
                              _PredictionRow(
                                name: result.predictions[i].name,
                                score: result.predictions[i].score,
                                top: i == 0,
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- EFFECTS ----------
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(title: 'Effects on your palm'),
                          const SizedBox(height: 12),
                          _DiseaseInfo(
                            diseaseId: result.diseaseId,
                            builder: (d) {
                              final symptoms = _diseaseList(d['symptoms']);
                              if (symptoms.isEmpty) {
                                return Text(
                                  isHealthy
                                      ? 'No disease was identified by the model in this image. Keep following good agricultural practices and monitor new leaf growth.'
                                      : 'The potential effects depend on the disease and its severity. Monitor affected leaves and other parts of the palm for changes.',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final s in symptoms)
                                    _BulletItem(
                                      text: s,
                                      color: isHealthy
                                          ? AppColors.healthyGreen
                                          : AppColors.diseased,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- TREATMENT ----------
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(
                              title: 'Recommended treatment & care'),
                          const SizedBox(height: 14),
                          _DiseaseInfo(
                            diseaseId: result.diseaseId,
                            builder: (d) {
                              final steps = _diseaseList(d['treatment']);
                              final items = steps.isNotEmpty
                                  ? steps
                                  : const [
                                      'Inspect the palm leaves regularly.',
                                      'Take clear photos of any suspicious areas.',
                                      'Maintain appropriate irrigation and care.',
                                      'Seek agricultural expert advice if symptoms persist or spread.',
                                      'Scan the palm again to monitor changes.',
                                    ];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    _NumberedItem(
                                      number: '${i + 1}',
                                      text: items[i],
                                      showLine: i < items.length - 1,
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F0E6),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: AppColors.healthyGreen, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Next step: monitor this palm and scan it '
                                    'again if its condition changes.',
                                    style: TextStyle(
                                      color: AppColors.healthyGreen,
                                      fontSize: 14,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- DISCLAIMER ----------
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.mutedText, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI predictions are for preliminary assessment and '
                            'do not replace professional agricultural diagnosis.',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ---------- BUTTONS ----------
                    _PillButton(
                      label: 'Save to my collection',
                      icon: Icons.bookmark_border_rounded,
                      style: _PillStyle.dark,
                      onPressed: () => _saveScan(context),
                    ),
                    const SizedBox(height: 12),
                    _PillButton(
                      label: 'Ask AI about this result',
                      icon: Icons.chat_bubble_outline_rounded,
                      style: _PillStyle.outline,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ChatbotScreen(
                              diseaseId: result.diseaseId,
                              confidence: result.confidence,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _PillButton(
                      label: 'Scan again',
                      icon: Icons.photo_camera_outlined,
                      style: _PillStyle.soft,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ScanPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const AppBottomNavigationBar(current: NavTab.history),
    );
  }
}

// ============================================================
// SMALL WIDGETS
// ============================================================

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEDEFEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small grey uppercase label, e.g. "CONFIDENCE".
class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionTitle({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (icon != null)
          Icon(icon, color: AppColors.mutedText, size: 22),
      ],
    );
  }
}

/// "● Diseased" / "● Healthy"
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isHealthy});
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? AppColors.healthyGreen : AppColors.diseased;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHealthy ? AppColors.softGreen : const Color(0xFFFBE7DD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isHealthy ? 'Healthy' : 'Diseased',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "● Needs assessment" (yellow) / "● Healthy" (green)
class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.isHealthy});
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final color =
        isHealthy ? AppColors.healthyGreen : const Color(0xFFB7791F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isHealthy ? AppColors.softGreen : const Color(0xFFFBEFCB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isHealthy ? 'Healthy' : 'Needs assessment',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of "Model predictions" with a bar.
class _PredictionRow extends StatelessWidget {
  const _PredictionRow({
    required this.name,
    required this.score,
    required this.top,
  });

  final String name;
  final double score; // 0..1
  final bool top; // highest prediction = green and bold

  @override
  Widget build(BuildContext context) {
    final value = score.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: top ? AppColors.softGreen : AppColors.pageBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 15,
              color: top ? AppColors.healthyGreen : AppColors.mutedText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color:
                              top ? AppColors.textDark : AppColors.mutedText,
                          fontSize: 15,
                          fontWeight: top ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: AppColors.inputBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.healthyGreen),
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

/// Colored dot + text.
class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7, left: 2),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lime number circle + text. "Prune: cut..." shows "Prune:" in bold.
class _NumberedItem extends StatelessWidget {
  final String number;
  final String text;
  final bool showLine;

  const _NumberedItem({
    required this.number,
    required this.text,
    this.showLine = false,
  });

  @override
  Widget build(BuildContext context) {
    // Bold the short word before ":" (e.g. "Prune:")
    final i = text.indexOf(':');
    final hasLead = i > 0 && i < 25;
    final lead = hasLead ? text.substring(0, i + 1) : '';
    final rest = hasLead ? text.substring(i + 1) : text;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: AppColors.inputBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: showLine ? 14 : 0),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  children: [
                    if (hasLead)
                      TextSpan(
                        text: lead,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    TextSpan(text: rest),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small ring with a check mark (filled by the confidence).
class _ConfidenceCircle extends StatelessWidget {
  final double confidence; // 0..1

  const _ConfidenceCircle({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final value = confidence.clamp(0.0, 1.0);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              backgroundColor: AppColors.inputBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.healthyGreen),
            ),
          ),
          const Icon(Icons.check_rounded,
              color: AppColors.healthyGreen, size: 20),
        ],
      ),
    );
  }
}

enum _PillStyle { dark, outline, soft }

/// Full-width pill button in three styles.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.style,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _PillStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (style) {
      _PillStyle.dark => AppColors.primary,
      _PillStyle.outline => Colors.white,
      _PillStyle.soft => const Color(0xFFE6F0E6),
    };
    final Color fg = style == _PillStyle.dark ? Colors.white : AppColors.primary;
    final Color iconColor =
        style == _PillStyle.dark ? AppColors.lime : AppColors.primary;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 22),
        label: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          shape: const StadiumBorder(),
          side: style == _PillStyle.outline
              ? const BorderSide(color: AppColors.primary, width: 1.6)
              : BorderSide.none,
        ),
      ),
    );
  }
}

// ============================================================
// DISEASE INFO from Firestore: diseases/{diseaseId}
// ============================================================

final Map<String, Future<Map<String, dynamic>>> _diseaseCache = {};

Future<Map<String, dynamic>> _loadDisease(String id) {
  return _diseaseCache.putIfAbsent(id, () async {
    if (id.isEmpty) return <String, dynamic>{};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('diseases')
          .doc(id)
          .get();
      return doc.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  });
}

/// Turns a Firestore list into clean items. Also handles lists that were
/// saved as one long text like "Item A · 1: Item B · 2: Item C".
List<String> _diseaseList(dynamic value) {
  final raw =
      value is List ? value.map((e) => e.toString()) : const <String>[];
  return raw
      .expand((s) => s.split('·'))
      .map((s) => s.replaceFirst(RegExp(r'^\s*\d+\s*:\s*'), '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class _DiseaseInfo extends StatelessWidget {
  const _DiseaseInfo({required this.diseaseId, required this.builder});
  final String diseaseId;
  final Widget Function(Map<String, dynamic> disease) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDisease(diseaseId),
      builder: (context, snapshot) => builder(snapshot.data ?? const {}),
    );
  }
}
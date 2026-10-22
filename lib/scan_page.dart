import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'History.dart';
import 'analysis_result_screen.dart';
import 'services/model_service.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();

  bool _cameraMode = false;
  bool _isAnalyzing = false;

  // The photo the user picked or took (null = no photo yet)
  File? _selectedImage;

  // Latest scans, shown in "Recent photos"
  List<ScanRecord> _recent = [];
  StreamSubscription<List<ScanRecord>>? _recentSub;

  @override
  void initState() {
    super.initState();
    // Wake the model server early so the first analysis is faster
    ModelService.wakeUp();

    _recentSub = HistoryRepository().watchScans().listen(
      (list) {
        if (mounted) setState(() => _recent = list.take(5).toList());
      },
      onError: (_) {}, // No recent photos if loading fails
    );
  }

  @override
  void dispose() {
    _recentSub?.cancel();
    super.dispose();
  }

  // ---------- Actions ----------

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 600,
      imageQuality: 70,
    );

    // The user closed the gallery or camera without choosing a photo
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _cameraMode = false; // Show the photo in the upload box
    });
  }

  Future<void> _analyzeImage() async {
    final image = _selectedImage;
    if (image == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      // Get the real prediction from the model.
      final result = await ModelService.explain(
        image,
        method: XaiMethod.gradcamPP,
      );

      if (!mounted) return;

      // Open the result screen with the selected image and prediction.
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AnalysisResultScreen(
            imageFile: image,
            result: result,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Analyze failed: $e');
      if (!mounted) return;
      _showMessage('Could not analyze the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );
  }

  void _openScan(ScanRecord r) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ScanDetailsScreen(record: r)),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons on the dark camera screen
      value: _cameraMode
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: _cameraMode ? _cameraView() : _uploadView(),
        bottomNavigationBar:
            const AppBottomNavigationBar(current: NavTab.scan),
      ),
    );
  }

  // =========================================================
  // UPLOAD MODE
  // =========================================================

  Widget _uploadView() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(dark: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _modeToggle(dark: false),
                  const SizedBox(height: 18),
                  _selectedImage == null ? _uploadBox() : _previewBox(),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 14),
                    _analyzeButton(),
                  ],
                  const SizedBox(height: 26),
                  _recentHeader(),
                  const SizedBox(height: 12),
                  _recentGrid(),
                  const SizedBox(height: 20),
                  _tipsCard(dark: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dashed box with "Browse files"
  Widget _uploadBox() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFB5BFB2),
        radius: 28,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F0E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.file_upload_outlined,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'Upload a photo of the palm',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG or PNG · up to 10 MB',
              style: TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                child: const Text(
                  'Browse files',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The chosen photo with a remove button
  Widget _previewBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_selectedImage!, fit: BoxFit.cover),
            Positioned(
              top: 12,
              right: 12,
              child: _glassCircle(
                icon: Icons.close_rounded,
                size: 40,
                onTap: _isAnalyzing
                    ? null
                    : () => setState(() => _selectedImage = null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyzeButton() {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: _isAnalyzing ? null : _analyzeImage,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: const StadiumBorder(),
        ),
        child: _isAnalyzing
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.lime,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Analyzing...',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppColors.lime, size: 20),
                  SizedBox(width: 10),
                  Text('Analyze photo',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _recentHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Recent photos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        GestureDetector(
          onTap: _openHistory,
          child: const Text(
            'See all',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // Up to 5 recent scan photos + the Gallery tile
  Widget _recentGrid() {
    final tiles = <Widget>[
      for (final r in _recent)
        GestureDetector(
          onTap: () => _openScan(r),
          child: ScanImage(
            url: r.imageUrl,
            isHealthy: r.isHealthy,
            width: double.infinity,
            height: double.infinity,
            radius: 22,
          ),
        ),
      // Gallery tile
      Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _pickImage(ImageSource.gallery),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: AppColors.lime, size: 32),
              SizedBox(height: 8),
              Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: EdgeInsets.zero,
      children: tiles,
    );
  }

  // =========================================================
  // CAMERA MODE
  // =========================================================

  Widget _cameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background photo
        Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
        // Light dark layer so the white text is readable
        Container(color: Colors.black.withValues(alpha: 0.12)),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(dark: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _modeToggle(dark: true),
              ),
              const SizedBox(height: 22),

              // Scan frame
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: CustomPaint(
                    painter: _FrameCornersPainter(),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: _glassPill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.lime,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Place the leaf inside the frame',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _tipsCard(dark: true),
              ),
              const SizedBox(height: 20),
              _cameraControls(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }

  // Thumbnail · shutter · history
  Widget _cameraControls() {
    final last = _recent.isNotEmpty ? _recent.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 52),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Last photo -> opens the gallery
          GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2.5),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: last == null
                  ? const Icon(Icons.image_outlined, color: Colors.white)
                  : ScanImage(
                      url: last.imageUrl,
                      isHealthy: last.isHealthy,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 13,
                    ),
            ),
          ),

          // Shutter -> opens the phone camera
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: 90,
              height: 90,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // History
          _glassCircle(
            icon: Icons.history_rounded,
            size: 56,
            onTap: _openHistory,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SHARED PIECES
  // =========================================================

  // Back button + title
  Widget _header({required bool dark}) {
    final back = dark
        ? _glassCircle(
            icon: Icons.chevron_left_rounded,
            size: 48,
            onTap: () => Navigator.maybePop(context),
          )
        : GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textDark, size: 28),
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: back),
            Text(
              'Scan a palm leaf',
              style: TextStyle(
                color: dark ? Colors.white : AppColors.textDark,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                shadows: dark
                    ? const [Shadow(color: Colors.black38, blurRadius: 8)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Upload / Camera switch
  Widget _modeToggle({required bool dark}) {
    Widget seg(String label, IconData icon, bool camera) {
      final sel = _cameraMode == camera;
      final Color bg = sel
          ? (dark ? AppColors.lime : AppColors.primary)
          : Colors.transparent;
      final Color fg = sel
          ? (dark ? AppColors.primary : Colors.white)
          : (dark ? Colors.white : AppColors.mutedText);

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _cameraMode = camera),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 21),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = Row(
      children: [
        seg('Upload', Icons.file_upload_outlined, false),
        seg('Camera', Icons.photo_camera_outlined, true),
      ],
    );

    if (!dark) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E9E3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: row,
      );
    }
    return _glass(radius: 28, padding: const EdgeInsets.all(4), child: row);
  }

  // "For best results" box
  Widget _tipsCard({required bool dark}) {
    final Color titleColor = dark ? Colors.white : AppColors.healthyGreen;
    final Color textColor =
        dark ? Colors.white.withValues(alpha: 0.9) : AppColors.healthyGreen;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined,
                color: dark ? AppColors.lime : AppColors.healthyGreen,
                size: 20),
            const SizedBox(width: 10),
            Text(
              'For best results',
              style: TextStyle(
                color: titleColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Natural daylight · No harsh shadows · Fill the frame',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (!dark) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F0E6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: content,
      );
    }
    return _glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: SizedBox(width: double.infinity, child: content),
    );
  }

  // Frosted glass box
  Widget _glass({
    required Widget child,
    double radius = 24,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassPill({required Widget child}) {
    return _glass(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: child,
    );
  }

  Widget _glassCircle({
    required IconData icon,
    required double size,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// PAINTERS
// =========================================================

/// Dashed rounded border around the upload box.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    const dash = 8.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Four lime corners of the camera scan frame.
class _FrameCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 46.0; // corner arm length
    const r = 18.0; // corner roundness
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(len, h),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:flutter/material.dart'; 
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_account.dart';
import 'forgot_password.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'dart:async';
import 'theme/app_colors.dart';
import 'widgets/auth_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SaafApp());
}

class SaafApp extends StatelessWidget {
  const SaafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Sa'af",
               theme: ThemeData(
           useMaterial3: true,
           fontFamily: GoogleFonts.inter().fontFamily,
           scaffoldBackgroundColor: const Color(0xFFF3F5F0),
         ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// COLORS
// ============================================================

const Color darkGreen = Color(0xFF17372A);
const Color buttonGreen = Color(0xFF1F6B45);
const Color onboardingBackground = Color(0xFFF4FFF5);
const Color textGreen = Color(0xFF17372A);

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _activeDot = 0;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();

    // Animate the 3 loading dots.
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _activeDot = (_activeDot + 1) % 3);
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),

          // Dark green overlay (lighter at top, darker at bottom)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF173F2C).withValues(alpha: 0.55),
                  const Color(0xFF173F2C).withValues(alpha: 0.70),
                  const Color(0xFF0F2A1D).withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),

                // Logo in a glass circle with a soft green glow
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lime.withValues(alpha: 0.35),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                                    child: ClipOval(
                    child: Transform.scale(
                      scale: 1.5,
                      child: Image.asset('assets/images/logo_light.png'),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "Sa'af",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Smart care for your date palms',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                  ),
                ),

                const Spacer(flex: 6),

                // Loading dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _activeDot;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? AppColors.lime
                            : AppColors.lime.withValues(alpha: 0.35),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                Text(
                  'AI-powered palm diagnosis',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// ONBOARDING
// ============================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  final List<OnboardingData> pages = const [
    OnboardingData(
      image: 'assets/images/onboarding_1.jpg',
      title: "Welcome to Sa'af",
      description:
          'Your smart companion for monitoring and caring for your date palm trees.',
      kind: OnboardingKind.welcome,
    ),
    OnboardingData(
      image: 'assets/images/onboarding_2.jpg',
      title: 'AI Disease\nClassification',
      description:
          'Snap a photo of a palm leaf and know instantly if it is healthy or diseased.',
      kind: OnboardingKind.detect,
    ),
    OnboardingData(
      image: 'assets/images/onboarding_3.png',
      title: 'Track Your\nPalm Health',
      description:
          'Review previous scans and follow how your palms improve over time.',
      kind: OnboardingKind.track,
    ),
  ];

  bool get _isLast => currentPage == pages.length - 1;

  void nextPage() {
    if (!_isLast) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      goToLogin();
    }
  }

  void goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Pages (photo + texts)
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => currentPage = i),
            itemBuilder: (context, i) =>
                _OnboardingPage(data: pages[i], index: i, count: pages.length),
          ),

          // Top bar: logo + Skip
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                                    SizedBox(
                    width: 44,
                    height: 44,
                    child: Transform.scale(
                      scale: 1.6,
                      child: Image.asset('assets/images/logo_light.png'),
                    ),
                  ),
                  const Spacer(),
                  if (!_isLast)
                    GestureDetector(
                      onTap: goToLogin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom button
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
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

// ============================================================
// ONBOARDING PAGE
// ============================================================

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.index,
    required this.count,
  });

  final OnboardingData data;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(data.image, fit: BoxFit.cover),

        // Dark green fade at the bottom so the text is readable
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                const Color(0xFF173F2C).withValues(alpha: 0.35),
                const Color(0xFF0F2A1D).withValues(alpha: 0.92),
                const Color(0xFF0F2A1D),
              ],
              stops: const [0.0, 0.45, 0.72, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 70, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Middle illustration (page 2 and 3 only)
                Expanded(
                  child: Center(
                    child: switch (data.kind) {
                      OnboardingKind.welcome => const SizedBox(),
                      OnboardingKind.detect => const _DetectIllustration(),
                      OnboardingKind.track => const _TrackIllustration(),
                    },
                  ),
                ),

                // Page indicator
                Row(
                  children: List.generate(count, (i) {
                    final active = i == index;
                    return Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: active ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.lime
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),

                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                // Space for the button
                const SizedBox(height: 122),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Page 2: scan frame + "Black Scorch detected" card
class _DetectIllustration extends StatelessWidget {
  const _DetectIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(180, 180),
          painter: _ScanFramePainter(),
        ),
        const SizedBox(height: 18),
        Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Black Scorch detected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: 0.98,
                              minHeight: 4,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.lime),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '98%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Lime corner brackets of the scan frame
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0; // corner length
    final w = size.width, h = size.height;
    // top-left
    canvas.drawLine(const Offset(0, l), Offset.zero, p);
    canvas.drawLine(Offset.zero, const Offset(l, 0), p);
    // top-right
    canvas.drawLine(Offset(w - l, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, l), p);
    // bottom-left
    canvas.drawLine(Offset(0, h - l), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(l, h), p);
    // bottom-right
    canvas.drawLine(Offset(w - l, h), Offset(w, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - l), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Page 3: "Scan history" glass card with a chart and 3 rows
class _TrackIllustration extends StatelessWidget {
  const _TrackIllustration();

  Widget _row(String label, Color dot) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Scan history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'This month',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomPaint(
            size: const Size(double.infinity, 80),
            painter: _ChartPainter(),
          ),
          const SizedBox(height: 4),
          _row('Healthy', AppColors.lime),
          _row('Black Scorch', AppColors.diseased),
          _row('Leaf Spots', const Color(0xFFF2C14E)),
        ],
      ),
    );
  }
}

// Simple rising line chart
class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pts = [0.85, 0.65, 0.78, 0.55, 0.62, 0.38, 0.30, 0.05];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * pts[i];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    // Soft fill under the line
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lime.withValues(alpha: 0.35),
            AppColors.lime.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.lime
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // End dot
    canvas.drawCircle(
      Offset(size.width, size.height * pts.last),
      4,
      Paint()..color = AppColors.lime,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// ONBOARDING DATA
// ============================================================

enum OnboardingKind { welcome, detect, track }

class OnboardingData {
  final String image;
  final String title;
  final String description;
  final OnboardingKind kind;

  const OnboardingData({
    required this.image,
    required this.title,
    required this.description,
    required this.kind,
  });
}
// ============================================================
// LOGIN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool isLoading = false;
  bool isGuestLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await AuthService().logIn(email: email, password: password);
      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleGuest() async {
    setState(() => isGuestLoading = true);
    try {
      await AuthService().signInAsGuest();
      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => isGuestLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(
              title: 'Welcome back',
              subtitle: 'Sign in to keep your palms healthy',
            ),
            AuthSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthLabel('Email'),
                  AuthTextField(
                    controller: emailController,
                    hint: 'name@example.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  const AuthLabel('Password'),
                  AuthTextField(
                    controller: passwordController,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: obscurePassword,
                    onToggleObscure: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                  const SizedBox(height: 14),

                  // Forgot password (right)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  PrimaryButton(
                    label: 'Log in',
                    showArrow: true,
                    loading: isLoading,
                    onPressed: handleLogin,
                  ),
                  const SizedBox(height: 20),

                  // "or" divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.inputBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or',
                            style: TextStyle(color: AppColors.mutedText)),
                      ),
                      Expanded(child: Divider(color: AppColors.inputBorder)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  OutlinePillButton(
                    label: isGuestLoading
                        ? 'Please wait...'
                        : 'Continue as a guest',
                    icon: Icons.person_outline,
                    onPressed: isGuestLoading ? null : handleGuest,
                  ),
                  const SizedBox(height: 40),

                  // Create account link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Create account',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CreateAccountScreen(),
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
          ],
        ),
      ),
    );
  }
}
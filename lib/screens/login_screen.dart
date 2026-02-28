import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/animations.dart';
import '../widgets/glass_widgets.dart';
import 'signup_screen.dart';
import 'public_dashboard.dart';
import 'officer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final user = await _firestoreService.getUser(credential.user!.uid);
      if (user == null) {
        _showError('User profile not found.');
        return;
      }

      if (user.role == 'OFFICER') {
        Navigator.pushReplacement(
          context,
          AppTheme.fadeSlideRoute(const OfficerDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          AppTheme.fadeSlideRoute(const PublicDashboard()),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ─── Animated Logo with Glow ──────────────────
                    ScaleIn(
                      delay: const Duration(milliseconds: 100),
                      child: BreathingGlow(
                        glowColor: AppTheme.policeColor,
                        maxBlur: 40,
                        child: AnimatedGradientBorder(
                          borderRadius: 28,
                          borderWidth: 1.5,
                          colors: const [
                            AppTheme.policeColor,
                            AppTheme.accentPurple,
                            AppTheme.accentCyan,
                          ],
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1565C0),
                                  Color(0xFF0D47A1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Icon(
                              Icons.security,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Title ────────────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: ShimmerEffect(
                        child: Text(
                          'RESQPIN',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
                      child: Text(
                        'Emergency Response System',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),

                    // ─── Email Field ──────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: Column(
                        children: [
                          _buildLabel('EMAIL ADDRESS'),
                          const SizedBox(height: 8),
                          GlassContainer(
                            padding: EdgeInsets.zero,
                            borderRadius: 14,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                hintText: 'name@example.com',
                                hintStyle: const TextStyle(
                                  color: AppTheme.textDisabled,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'Enter your email';
                                if (!val.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Password Field ───────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 550),
                      child: Column(
                        children: [
                          _buildLabel('PASSWORD'),
                          const SizedBox(height: 8),
                          GlassContainer(
                            padding: EdgeInsets.zero,
                            borderRadius: 14,
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                hintText: '••••••••',
                                hintStyle: const TextStyle(
                                  color: AppTheme.textDisabled,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Enter your password';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ─── Login Button ─────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 650),
                      child: GradientLoadingButton(
                        label: 'Login Securely',
                        icon: Icons.arrow_forward,
                        isLoading: _isLoading,
                        onPressed: _login,
                        color: AppTheme.policeColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Sign Up Link ─────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 750),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              AppTheme.fadeSlideRoute(const SignupScreen()),
                            ),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.inter(
                                color: AppTheme.policeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/sos_service.dart';
import '../models/user_model.dart';
import '../constants.dart';
import 'public_dashboard.dart';
import 'officer_dashboard.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  String _selectedRole = 'PUBLIC';
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    if (_selectedRole == 'OFFICER') {
      if (!isOfficialEmail(email)) {
        _showError(
          'Officer accounts require an official government email.\n'
          'Allowed domains: police.gov.in, health.gov.in, '
          'fireservice.gov.in, coastguard.gov.in',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signUp(
        email: email,
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      String? department;
      if (_selectedRole == 'OFFICER') {
        department = getDepartmentFromEmail(email);
      }

      String? uniqueCode;
      if (_selectedRole == 'PUBLIC') {
        uniqueCode = SOSService.generateUniqueCode();
      }

      final userModel = UserModel(
        uid: uid,
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        email: email,
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        department: department,
        uniqueCode: uniqueCode,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createUser(userModel);

      if (_selectedRole == 'PUBLIC') {
        await _firestoreService.getFamilyLink(uid);
      }

      if (!mounted) return;

      if (_selectedRole == 'OFFICER') {
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Create Account',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Role Selection ─────────────────────────────
                  Text(
                    'SELECT YOUR ROLE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.person_outline,
                          label: 'PUBLIC',
                          isSelected: _selectedRole == 'PUBLIC',
                          color: AppTheme.ambulanceColor,
                          onTap: () => setState(() => _selectedRole = 'PUBLIC'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.security,
                          label: 'OFFICER',
                          isSelected: _selectedRole == 'OFFICER',
                          color: AppTheme.policeColor,
                          onTap: () =>
                              setState(() => _selectedRole = 'OFFICER'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _selectedRole == 'OFFICER'
                        ? Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.policeColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.policeColor.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFF64B5F6),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Officer accounts require an official email:\n'
                                    '@police.gov.in  @health.gov.in\n'
                                    '@fireservice.gov.in  @coastguard.gov.in',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF90CAF9),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // ─── Name ───────────────────────────────────────
                  _buildLabel('FULL NAME'),
                  const SizedBox(height: 8),
                  _buildGlassField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Enter name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ─── Age & Gender Row ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('AGE'),
                            const SizedBox(height: 8),
                            _buildGlassField(
                              controller: _ageController,
                              hint: 'Age',
                              icon: Icons.cake_outlined,
                              keyboard: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'Enter age';
                                final age = int.tryParse(val.trim());
                                if (age == null || age < 1 || age > 120)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('GENDER'),
                            const SizedBox(height: 8),
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              borderRadius: 14,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.wc_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                dropdownColor: AppTheme.surfaceCard,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                items: _genders.map((g) {
                                  return DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _selectedGender = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Email ──────────────────────────────────────
                  _buildLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  _buildGlassField(
                    controller: _emailController,
                    hint: 'name@example.com',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Enter email';
                      if (!val.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Password ───────────────────────────────────
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 14,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter password';
                        if (val.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Phone ──────────────────────────────────────
                  _buildLabel('PHONE NUMBER'),
                  const SizedBox(height: 8),
                  _buildGlassField(
                    controller: _phoneController,
                    hint: '+91 XXXXX XXXXX',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Enter phone number';
                      if (val.trim().length < 10) return 'Invalid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ─── Sign Up Button ─────────────────────────────
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.policeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: AppTheme.policeColor.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'CREATE ACCOUNT',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
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
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textDisabled),
          prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

// ─── Role Selection Card Widget ──────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppTheme.surfaceCard.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : AppTheme.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppTheme.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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

    // ─── STRICT DOMAIN VALIDATION FOR OFFICERS ───────────────────────────
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
      // Create Firebase Auth account
      final credential = await _authService.signUp(
        email: email,
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // Derive department for officers
      String? department;
      if (_selectedRole == 'OFFICER') {
        department = getDepartmentFromEmail(email);
      }

      // Generate unique code for public users
      String? uniqueCode;
      if (_selectedRole == 'PUBLIC') {
        uniqueCode = SOSService.generateUniqueCode();
      }

      // Create user profile in Firestore
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

      // Initialize family link for PUBLIC users
      if (_selectedRole == 'PUBLIC') {
        await _firestoreService.getFamilyLink(uid);
      }

      if (!mounted) return;

      // Navigate based on role
      if (_selectedRole == 'OFFICER') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OfficerDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PublicDashboard()),
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Role Selection ─────────────────────────────────
                Text(
                  'I am a...',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person,
                        label: 'PUBLIC',
                        isSelected: _selectedRole == 'PUBLIC',
                        color: const Color(0xFF43A047),
                        onTap: () => setState(() => _selectedRole = 'PUBLIC'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.shield,
                        label: 'OFFICER',
                        isSelected: _selectedRole == 'OFFICER',
                        color: const Color(0xFF1565C0),
                        onTap: () => setState(() => _selectedRole = 'OFFICER'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedRole == 'OFFICER')
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFF64B5F6),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Officer accounts require an official email:\n'
                            '@police.gov.in  @health.gov.in\n'
                            '@fireservice.gov.in  @coastguard.gov.in',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF90CAF9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ─── Name ───────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 14),

                // ─── Age & Gender Row ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter age';
                          }
                          final age = int.tryParse(val.trim());
                          if (age == null || age < 1 || age > 120) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: _genders.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGender = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── Email ──────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter email';
                    if (!val.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ─── Password ───────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter password';
                    if (val.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ─── Phone ──────────────────────────────────────────
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter phone number';
                    }
                    if (val.trim().length < 10) return 'Invalid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ─── Sign Up Button ─────────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                        : const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF2A2A3C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.grey,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

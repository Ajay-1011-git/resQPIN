import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app_theme.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_dashboard.dart';
import 'screens/officer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  runApp(const ResQPINApp());
}

class ResQPINApp extends StatelessWidget {
  const ResQPINApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQPIN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase Auth state and routes to the correct screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'ResQPIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Not authenticated
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Authenticated — determine role and route
        return _RoleRouter(uid: snapshot.data!.uid);
      },
    );
  }
}

/// Fetches user profile from Firestore and routes to the correct dashboard.
class _RoleRouter extends StatelessWidget {
  final String uid;
  const _RoleRouter({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirestoreService().getUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // Profile not found — force to login
          return const LoginScreen();
        }

        if (user.role == 'OFFICER') {
          return const OfficerDashboard();
        }
        return const PublicDashboard();
      },
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'board_screen.dart';
import 'login_screen.dart';

/// Routes the whole app on auth state. Signed-in users land on the board;
/// signed-out users are sent to login. `authStateChanges()` is what drives it,
/// so sign-in/sign-out swaps screens automatically.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: user != null
              ? BoardScreen(key: const ValueKey('board'), user: user)
              : const LoginScreen(key: ValueKey('login')),
        );
      },
    );
  }
}

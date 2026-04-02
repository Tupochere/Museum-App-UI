import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'registration_screen.dart';

/// Manages switching between Login and Registration screens
/// without pushing routes onto the navigator stack.
/// This ensures AuthStateNotifier's rebuild in main.dart works cleanly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginScreen(
        onSwitchToRegister: () => setState(() => _showLogin = false),
      );
    }
    return RegistrationScreen(
      onSwitchToLogin: () => setState(() => _showLogin = true),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/sign_in_screen.dart';
import '../service/auth_service.dart';

class AuthGate extends StatefulWidget {
  final Widget signedInApp;

  const AuthGate({required this.signedInApp, super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? authSubscription;
  Session? currentSession;

  @override
  void initState() {
    super.initState();

    currentSession = AuthService.currentSession;

    authSubscription = AuthService.authStateChanges.listen((authState) {
      if (!mounted) return;

      setState(() {
        currentSession = authState.session;
      });
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentSession == null) {
      return const SignInScreen();
    }

    return widget.signedInApp;
  }
}

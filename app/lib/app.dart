import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// Root MaterialApp. The home is an [AuthGate] that swaps between splash,
/// onboarding, and the authenticated home based on [AuthController.status].
class BeefApp extends StatelessWidget {
  const BeefApp({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: controller,
      child: MaterialApp(
        title: 'BEEF',
        debugShowCheckedModeBanner: false,
        theme: BeefTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = AuthScope.of(context);
    switch (controller.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const OnboardingFlow();
      case AuthStatus.authenticated:
        return const HomeScreen();
    }
  }
}

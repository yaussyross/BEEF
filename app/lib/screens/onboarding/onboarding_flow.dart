import 'package:flutter/material.dart';

import 'age_gate_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

enum _OnboardingStep { ageGate, register, login }

/// The onboarding sequence, managed with a simple internal step state machine
/// (no nested Navigator). A completed register/login flips `AuthStatus` to
/// authenticated and the parent `AuthGate` swaps this whole flow out for the
/// home screen — so there are no stale pushed routes left behind.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  _OnboardingStep _step = _OnboardingStep.ageGate;
  String? _birthdate;

  void _goToRegister(String? birthdate) {
    // Registration requires a birthdate. If it is ever missing (e.g. a direct
    // jump from login), route back through the non-skippable age gate first.
    if (birthdate == null || birthdate.isEmpty) {
      setState(() => _step = _OnboardingStep.ageGate);
      return;
    }
    setState(() {
      _birthdate = birthdate;
      _step = _OnboardingStep.register;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _OnboardingStep.ageGate:
        return AgeGateScreen(
          onContinue: _goToRegister,
          onHaveAccount: () => setState(() => _step = _OnboardingStep.login),
        );
      case _OnboardingStep.register:
        return RegisterScreen(
          birthdate: _birthdate ?? '',
          onBack: () => setState(() => _step = _OnboardingStep.ageGate),
          onHaveAccount: () => setState(() => _step = _OnboardingStep.login),
        );
      case _OnboardingStep.login:
        return LoginScreen(
          onBack: () => setState(() => _step = _OnboardingStep.ageGate),
          // New users must pass the age gate before registering.
          onRegister: () => setState(() => _step = _OnboardingStep.ageGate),
        );
    }
  }
}

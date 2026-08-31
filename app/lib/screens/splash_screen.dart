import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';
import '../widgets/beef_wordmark.dart';

/// Shown while the session is being restored from the keystore.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const BeefWordmark(),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: BeefColors.lime),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';
import '../widgets/beef_wordmark.dart';

/// Shown while the session is being restored from the keystore.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              BeefWordmark(),
              SizedBox(height: 40),
              CircularProgressIndicator(color: BeefColors.lime),
            ],
          ),
        ),
      ),
    );
  }
}

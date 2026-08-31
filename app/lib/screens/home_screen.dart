import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../theme/beef_colors.dart';
import '../widgets/beef_wordmark.dart';
import '../widgets/brand_button.dart';

/// Placeholder authenticated home. The proximity grid, profiles, and chat land
/// in later slices — this is the post-login destination for the auth slice.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController controller = AuthScope.of(context);
    final String display = _displayName(controller);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BEEF'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => controller.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const BeefWordmark(compact: true),
                const SizedBox(height: 24),
                Text(
                  'Welcome back, $display.',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'The sizzling grid is on its way. You are in — friends, dates, '
                  'and hookups, all a cut above the rest.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: BeefColors.cream.withValues(alpha: 0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                BrandButton(
                  label: 'Sign out',
                  onPressed: () => controller.signOut(),
                  accent: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _displayName(AuthController controller) {
    final String? name = controller.profile?.displayName;
    if (name != null && name.isNotEmpty) return name;
    return controller.user?.email ?? 'there';
  }
}

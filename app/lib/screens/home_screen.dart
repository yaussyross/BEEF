import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../theme/beef_colors.dart';
import 'grid_screen.dart';

/// Authenticated home: bottom-tab shell with the proximity grid as the landing
/// tab. Later slices add chat (and any further tabs) here — the grid stays the
/// spine.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const <Widget>[
          GridScreen(),
          _SoonTab(
            icon: Icons.chat_bubble_outline,
            title: 'Chats',
            message: 'Saucy conversations are marinating — chat lands next.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int index) =>
            setState(() => _tab = index),
        backgroundColor: BeefColors.char,
        indicatorColor: BeefColors.steak.withValues(alpha: 0.35),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Grid',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
        ],
      ),
    );
  }
}

/// Placeholder for tabs whose slices have not landed yet. Sign-out lives here
/// until a settings tab exists.
class _SoonTab extends StatelessWidget {
  const _SoonTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController controller = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title.toUpperCase())),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 56, color: BeefColors.sizzle),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: BeefColors.cream.withValues(alpha: 0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => controller.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

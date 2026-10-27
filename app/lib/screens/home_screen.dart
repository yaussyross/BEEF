import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';
import 'grid_screen.dart';
import 'inbox_screen.dart';

/// Authenticated home: bottom-tab shell with the proximity grid as the landing
/// tab and live inbox.
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
        children: const <Widget>[GridScreen(), InboxScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int index) => setState(() => _tab = index),
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

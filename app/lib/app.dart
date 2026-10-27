import 'dart:async';

import 'package:flutter/material.dart';

import 'api/chat_api.dart';
import 'api/http_client.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'chat/chat_controller.dart';
import 'chat/chat_scope.dart';
import 'chat/chat_socket.dart';
import 'config/api_config.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// The chat session and navigation stack belong to the authenticated account.
/// Signing out disposes sockets, timers, drafts, and every protected route.
class BeefApp extends StatefulWidget {
  const BeefApp({super.key, required this.controller});
  final AuthController controller;

  @override
  State<BeefApp> createState() => _BeefAppState();
}

class _BeefAppState extends State<BeefApp> with WidgetsBindingObserver {
  ChatController? _chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_sessionChanged);
    _syncChat();
  }

  void _syncChat() {
    final id = widget.controller.isAuthenticated
        ? widget.controller.user?.id
        : null;
    if (_chat?.userId == id) {
      return;
    }
    _chat?.dispose();
    _chat = id == null
        ? null
        : ChatController(
            api: ChatApi(
              ApiClient(
                baseUrl: ApiConfig.baseUrl,
                tokenStore: widget.controller.tokenStore,
              ),
            ),
            userId: id,
            socket: NativeChatSocket(),
            onSessionExpired: () => unawaited(widget.controller.signOut()),
          );
    if (_chat != null) {
      unawaited(_chat!.start());
    }
  }

  void _sessionChanged() {
    _syncChat();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chat?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_sessionChanged);
    _chat?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp(
      key: ValueKey(_chat?.userId ?? 'signed-out'),
      title: 'BEEF',
      debugShowCheckedModeBanner: false,
      theme: BeefTheme.dark,
      home: const AuthGate(),
    );
    if (_chat != null) {
      app = ChatScope(controller: _chat!, child: app);
    }
    return AuthScope(controller: widget.controller, child: app);
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    switch (AuthScope.of(context).status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const OnboardingFlow();
      case AuthStatus.authenticated:
        return const HomeScreen();
    }
  }
}

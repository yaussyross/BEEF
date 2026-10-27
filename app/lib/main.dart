import 'dart:async';

import 'package:flutter/material.dart';

import 'api/auth_api.dart';
import 'api/http_client.dart';
import 'api/token_store.dart';
import 'app.dart';
import 'auth/auth_controller.dart';
import 'config/api_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!ApiConfig.isConfigured) {
    runApp(const MaterialApp(home: Scaffold(body: SafeArea(child: Center(
      child: Padding(padding: EdgeInsets.all(24), child: Text(
        'BEEF test build — no server configured.\nUse a build configured for the approved private test server.')),
    )))));
    return;
  }

  final TokenStore tokenStore = const SecureTokenStore();
  final ApiClient apiClient = ApiClient(
    baseUrl: ApiConfig.baseUrl,
    tokenStore: tokenStore,
  );
  final AuthController controller = AuthController(
    api: AuthApi(apiClient),
    tokenStore: tokenStore,
  );

  // Kick off session restore without blocking first paint — the splash screen
  // shows while the keystore/network round-trip resolves.
  unawaited(controller.restore());

  runApp(BeefApp(controller: controller));
}

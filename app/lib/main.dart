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

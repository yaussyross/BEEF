import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Exposes the [AuthController] to the widget tree via an [InheritedNotifier],
/// so onboarding/home screens can call register/login/signOut without pulling in
/// a state-management package.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Subscribe to the controller (use inside `build`).
  static AuthController of(BuildContext context) {
    final AuthScope? scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!.notifier!;
  }

  /// Read the controller without subscribing (use inside event handlers).
  static AuthController read(BuildContext context) {
    final AuthScope? scope =
        context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}

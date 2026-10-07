import 'package:flutter/widgets.dart';

import 'chat_controller.dart';

class ChatScope extends InheritedNotifier<ChatController> {
  const ChatScope({
    super.key,
    required ChatController controller,
    required super.child,
  }) : super(notifier: controller);

  static ChatController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatScope>()!.notifier!;
  static ChatController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatScope>()!.notifier!;
}

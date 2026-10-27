// Offline-only browser preview. No auth, real accounts, sockets or backend calls.
import 'package:flutter/material.dart';
import 'api/chat_api.dart';
import 'chat/chat_controller.dart';
import 'chat/chat_scope.dart';
import 'models/chat_message.dart';
import 'screens/conversation_screen.dart';
import 'screens/onboarding/age_gate_screen.dart';
import 'theme/app_theme.dart';
import '../test/chat_test_helpers.dart';

void main() => runApp(const OfflinePreview());
class OfflinePreview extends StatefulWidget {
  const OfflinePreview({super.key});
  @override
  State<OfflinePreview> createState() => _OfflinePreviewState();
}
class _OfflinePreviewState extends State<OfflinePreview> {
  late final ChatController chat;
  @override
  void initState() {
    super.initState();
    final api = FakeChatApi();
    api.onHistory = (_, __) async => ChatHistory([
      ChatMessage.fromJson(messageJson(body: 'Synthetic preview greeting. No real person or server.')),
    ], null);
    chat = ChatController(api: api, userId: 'me', socket: FakeChatSocket());
  }
  @override
  void dispose() { chat.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ChatScope(controller: chat, child: MaterialApp(
    title: 'BEEF synthetic offline preview', theme: BeefTheme.dark,
    builder: (context, child) => Column(children: [
      const SafeArea(bottom: false, child: Material(color: Colors.black, child: Padding(
        padding: EdgeInsets.all(8), child: Text('SYNTHETIC OFFLINE PREVIEW · NO BACKEND', style: TextStyle(color: Colors.white, fontSize: 12)),
      ))),
      Expanded(child: child!),
    ]),
    home: Builder(builder: (context) => Scaffold(appBar: AppBar(title: const Text('BEEF preview')),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(20), child: Text('Browser preview only. Not native iOS. No real accounts or messages.')),
        FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConversationScreen(thread: testThread))), child: const Text('Try synthetic chat')),
        TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AgeGateScreen(
          onContinue: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview only: registration is disabled.'))),
          onHaveAccount: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview only: login is disabled.'))),
        ))), child: const Text('View adult gate')),
      ])),
    )),
  ));
}

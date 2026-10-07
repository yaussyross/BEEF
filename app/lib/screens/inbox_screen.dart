import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../chat/chat_scope.dart';
import '../theme/beef_colors.dart';
import 'conversation_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHATS'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthScope.read(context).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: chat.refreshInbox,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                chat.connected ? 'Good conversation starts here.' : 'Live chat is reconnecting. Messages can still send over HTTP.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (chat.inboxLoading && chat.threads.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (chat.inboxError != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(chat.inboxError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: chat.refreshInbox,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            if (!chat.inboxLoading &&
                chat.inboxError == null &&
                chat.threads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 56,
                      color: BeefColors.sizzle,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Break the ice.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Find someone on the grid and say hello from their profile.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final thread in chat.threads)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: BeefColors.steak,
                  child: Text(
                    thread.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(color: BeefColors.cream),
                  ),
                ),
                title: Text(
                  thread.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: thread.unreadCount > 0
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  thread.lastMessage?.displayBody ?? 'Say hello.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: thread.unreadCount > 0
                    ? Badge(
                        label: Text(
                          thread.unreadCount > 99
                              ? '99+'
                              : '${thread.unreadCount}',
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  if (_opening) {
                    return;
                  }
                  _opening = true;
                  try {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConversationScreen(thread: thread),
                      ),
                    );
                  } finally {
                    _opening = false;
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

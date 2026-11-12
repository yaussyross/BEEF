import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_controller.dart';
import '../chat/chat_scope.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../theme/beef_colors.dart';
import 'rating_screen.dart';
import 'safety_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.thread});
  final ChatThread thread;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _draft = TextEditingController();
  ChatController? _chat;
  bool _openingAction = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chat == null) {
      _chat = ChatScope.read(context);
      // Defer the notifier mutation until the route has finished building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_chat!.openThread(widget.thread));
        }
      });
    }
  }

  @override
  void dispose() {
    _chat?.leaveThread(widget.thread.id);
    _draft.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final chat = _chat!;
    final text = _draft.text;
    if (chat.sending ||
        chat.unavailable ||
        text.trim().isEmpty ||
        text.length > 4000) {
      return;
    }
    _draft.clear();
    final queued = await chat.send(text);
    if (!queued && mounted && _draft.text.isEmpty) {
      _draft.text = text;
    }
  }

  Future<void> _rate() async {
    if (_openingAction) return;
    setState(() => _openingAction = true);
    final chat = _chat!;
    chat.leaveThread(widget.thread.id);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RatingScreen(userId: widget.thread.otherUserId),
      ));
    } finally {
      if (mounted) {
        await chat.openThread(widget.thread);
        if (mounted) setState(() => _openingAction = false);
      }
    }
  }

  Future<void> _safety({String? messageId}) async {
    if (_openingAction) return;
    setState(() => _openingAction = true);
    final chat = _chat!;
    chat.leaveThread(widget.thread.id);
    final blocked = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => SafetyScreen(userId: widget.thread.otherUserId, threadId: widget.thread.id, messageId: messageId),
    ));
    if (!mounted) return;
    if (blocked == true) {
      chat.confirmBlock(widget.thread.otherUserId);
      Navigator.of(context).pop();
    } else {
      await chat.openThread(widget.thread);
      if (mounted) setState(() => _openingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);
    final isCurrent = chat.activeThread?.id == widget.thread.id;
    final messages = isCurrent ? chat.messages : const <ChatMessage>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.thread.displayName),
        actions: [
          IconButton(tooltip: 'Safety options', onPressed: _openingAction ? null : _safety,
            icon: const Icon(Icons.shield_outlined)),
          IconButton(
            tooltip: 'Rate this Guy',
            onPressed: chat.unavailable || _openingAction ? null : _rate,
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: chat.historyLoading ? null : chat.refreshHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    chat.connected ? Icons.check_circle_outline : Icons.sync,
                    size: 16,
                    color: BeefColors.lime,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chat.connected
                          ? 'Live chat'
                          : 'Reconnecting · HTTP fallback available',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (chat.historyError != null && isCurrent)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.historyError!,
                        style: const TextStyle(color: BeefColors.sizzle),
                      ),
                    ),
                    if (!chat.unavailable)
                      TextButton(
                        onPressed: chat.refreshHistory,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: !isCurrent || (chat.historyLoading && messages.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : chat.unavailable
                  ? const Center(
                      child: Text('This conversation is unavailable.'),
                    )
                  : messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'A fresh conversation.\nSay something good.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length + (chat.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Center(
                            child: TextButton(
                              onPressed: chat.loadingMore
                                  ? null
                                  : chat.loadOlder,
                              child: Text(
                                chat.loadingMore
                                    ? 'Loading…'
                                    : 'Load older messages',
                              ),
                            ),
                          );
                        }
                        final message = messages[index];
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          own: message.senderId == chat.userId,
                          report: message.senderId == chat.userId || _openingAction ? null : () => _safety(messageId: message.id),
                          retry: chat.sending
                              ? null
                              : () => chat.retry(message.clientMessageId),
                        );
                      },
                    ),
            ),
            if (!chat.unavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Say hello…',
                          labelText: 'Message',
                          counterText: '',
                          errorText: _draft.text.length > 4000
                              ? 'This message is too long.'
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed:
                          !isCurrent ||
                              chat.sending ||
                              _draft.text.trim().isEmpty ||
                              _draft.text.length > 4000
                          ? null
                          : _send,
                      icon: chat.sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.own,
    this.retry,
    this.report,
  });
  final ChatMessage message;
  final bool own;
  final VoidCallback? retry;
  final VoidCallback? report;

  @override
  Widget build(BuildContext context) {
    final local = message.createdAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: own
              ? BeefColors.beefer
              : BeefColors.berry.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isVisible) const Icon(Icons.shield_outlined, size: 18),
            Text(message.displayBody),
            if (report != null) TextButton.icon(onPressed: report,
              icon: const Icon(Icons.flag_outlined, size: 16), label: const Text('Report message')),
            const SizedBox(height: 5),
            Text(
              message.delivery == MessageDelivery.sending
                  ? 'Sending…'
                  : message.delivery == MessageDelivery.failed
                  ? 'Not sent'
                  : time,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (message.delivery == MessageDelivery.failed) ...[
              const SizedBox(height: 5),
              Text(
                message.error ?? 'Check your connection.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(onPressed: retry, child: const Text('Retry message')),
            ],
          ],
        ),
      ),
    );
  }
}

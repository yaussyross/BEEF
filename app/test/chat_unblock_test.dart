import 'dart:async';

import 'package:beef/models/chat_thread.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_helpers.dart';

class DeferredInboxApi extends FakeChatApi {
  Future<List<ChatThread>> Function()? onInbox;
  @override
  Future<List<ChatThread>> inbox() => onInbox?.call() ?? super.inbox();
}

void main() {
  test('fresh authorized inbox recovers peer unblock without restoring stale cache', () async {
    final api = FakeChatApi();
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
    );
    addTearDown(chat.dispose);
    await chat.openThread(testThread);
    await Future<void>.delayed(Duration.zero);
    chat.confirmBlock('other');
    api.threads = [];
    await chat.refreshInbox();
    expect(chat.unavailable, isTrue);
    api.threads = [testThread];
    await chat.refreshInbox();
    expect(chat.unavailable, isFalse);
    expect(chat.messages, isEmpty);
  });

  test('inbox started before a block cannot undo the block', () async {
    final api = DeferredInboxApi();
    final chat = ChatController(
      api: api,
      userId: 'me',
      socket: FakeChatSocket(),
    );
    addTearDown(chat.dispose);
    await chat.openThread(testThread);
    await Future<void>.delayed(Duration.zero);
    final pending = Completer<List<ChatThread>>();
    api.onInbox = () => pending.future;
    final refresh = chat.refreshInbox();
    chat.confirmBlock('other');
    pending.complete([testThread]);
    await refresh;
    expect(chat.unavailable, isTrue);
    expect(chat.threads, isEmpty);
  });
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/chat_api.dart';
import '../api/http_client.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import 'chat_socket.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.api,
    required this.userId,
    required this.socket,
    this.onSessionExpired,
    this.ackTimeout = const Duration(seconds: 8),
    this.pollInterval = const Duration(seconds: 15),
  }) {
    _subscription = socket.events.listen(_onEvent);
  }

  final ChatApi api;
  final String userId;
  final ChatSocket socket;
  final VoidCallback? onSessionExpired;
  final Duration ackTimeout, pollInterval;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  Timer? _poll;
  bool _disposed = false, _foreground = true, _connecting = false;
  bool _connected = false, _inboxLoading = false, _historyLoading = false;
  bool _loadingMore = false, _sending = false, _historyReady = false;
  int _historyGeneration = 0;
  String? _inboxError, _historyError;
  List<ChatThread> _threads = [];
  ChatThread? _activeThread;
  final _history = <String, List<ChatMessage>>{};
  final _cursors = <String, String?>{};
  final _historyAnchors = <String, String?>{};
  final _blockedUsers = <String>{};
  final _blockedThreads = <String>{};
  Completer<ChatMessage>? _ack;
  String? _ackClientId;

  List<ChatThread> get threads => List.unmodifiable(_threads);
  List<ChatMessage> get messages =>
      List.unmodifiable(_history[_activeThread?.id] ?? []);
  ChatThread? get activeThread => _activeThread;
  bool get inboxLoading => _inboxLoading;
  bool get historyLoading => _historyLoading;
  bool get loadingMore => _loadingMore;
  bool get sending => _sending;
  bool get hasMore => _cursors[_activeThread?.id] != null;
  bool get connected => _connected;
  bool get unavailable => _blockedUsers.contains(_activeThread?.otherUserId);
  String? get inboxError => _inboxError;
  String? get historyError => _historyError;

  Future<void> start() async {
    _poll ??= Timer.periodic(pollInterval, (_) {
      if (!_foreground || _disposed) {
        return;
      }
      unawaited(refreshInbox());
      if (_activeThread != null && !unavailable) {
        unawaited(_loadHistory());
      }
      if (!_connected) {
        unawaited(_connect());
      }
    });
    await refreshInbox();
    if (!_disposed && _foreground) {
      await _connect();
    }
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) {
      return;
    }
    _foreground = value;
    if (!value) {
      _connected = false;
      _restartHydration();
      unawaited(socket.disconnect());
      _notify();
    } else {
      unawaited(refreshInbox());
      unawaited(refreshHistory());
      unawaited(_connect());
    }
  }

  Future<void> _connect() async {
    if (_connecting || _disposed || !_foreground) {
      return;
    }
    _connecting = true;
    try {
      // A protected REST request refreshes expired JWTs before the WS upgrade.
      await refreshInbox();
      if (_disposed || !_foreground) {
        return;
      }
      final token = await api.client.tokenStore.readAccessToken();
      if (token == null || token.isEmpty || _disposed || !_foreground) {
        return;
      }
      await socket.connect(api.client.baseUrl, token);
    } catch (_) {
      _connected = false; // REST remains available and reconnection is bounded.
    } finally {
      _connecting = false;
      _notify();
    }
  }

  Future<void> refreshInbox() async {
    if (_inboxLoading || _disposed) {
      return;
    }
    _inboxLoading = true;
    _inboxError = null;
    _notify();
    try {
      final result = await api.inbox();
      if (_disposed) {
        return;
      }
      _threads = result
          .where((t) => !_blockedUsers.contains(t.otherUserId))
          .toList();
    } catch (error) {
      if (!_disposed) {
        _inboxError = _describe(error);
      }
    } finally {
      _inboxLoading = false;
      _notify();
    }
  }

  Future<ChatThread> startThread(String otherUserId) async {
    try {
      final thread = await api.startThread(otherUserId);
      if (!_disposed) {
        _threads = [thread, ..._threads.where((t) => t.id != thread.id)];
        _notify();
      }
      return thread;
    } catch (error) {
      _describe(error);
      rethrow;
    }
  }

  Future<void> openThread(ChatThread thread) async {
    if (_disposed) {
      return;
    }
    _historyGeneration++;
    _activeThread = thread;
    _historyLoading = false;
    _loadingMore = false;
    _historyReady = false;
    _historyError = null;
    _notify();
    await refreshHistory();
  }

  void leaveThread(String threadId) {
    if (_activeThread?.id != threadId || _disposed) {
      return;
    }
    _historyGeneration++;
    _activeThread = null;
    _historyLoading = false;
    _loadingMore = false;
    _historyReady = false;
    // No notification during a route's dispose/build phase.
    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(refreshInbox());
      }
    });
  }

  Future<void> refreshHistory() => _loadHistory(reset: true);
  Future<void> loadOlder() => _loadHistory(older: true);

  Future<void> _loadHistory({bool older = false, bool reset = false}) async {
    final thread = _activeThread;
    if (_disposed ||
        thread == null ||
        unavailable ||
        _historyLoading ||
        _loadingMore) {
      return;
    }
    if (older && !hasMore) {
      return;
    }
    final generation = _historyGeneration;
    final beforeIds = (_history[thread.id] ?? []).map((m) => m.id).toSet();
    if (older) {
      _loadingMore = true;
    } else {
      _historyLoading = true;
    }
    _historyError = null;
    _notify();
    try {
      final page = await api.history(
        thread.id,
        cursor: older ? _cursors[thread.id] : null,
      );
      if (_disposed || generation != _historyGeneration) {
        return;
      }
      final gap =
          !older &&
          page.messages.isNotEmpty &&
          _historyAnchors[thread.id] != null &&
          !page.messages.any((m) => m.id == _historyAnchors[thread.id]);
      if (reset || gap) {
        // Keep unsent drafts; a reconnect starts a contiguous history window.
        _history[thread.id] = (_history[thread.id] ?? [])
            .where(
              (m) =>
                  m.delivery != MessageDelivery.sent ||
                  !beforeIds.contains(m.id),
            )
            .toList();
      }
      for (final message in page.messages) {
        _merge(message);
      }
      if (reset ||
          gap ||
          older ||
          _historyAnchors[thread.id] == null ||
          !_cursors.containsKey(thread.id)) {
        _cursors[thread.id] = page.nextCursor;
      }
      if (!older) {
        _historyAnchors[thread.id] = page.messages.isEmpty
            ? null
            : page.messages.first.id;
      }
      _historyReady = true;
      _markRead();
    } catch (error) {
      if (!_disposed && generation == _historyGeneration) {
        _historyError = _describe(error);
        if (error is ApiException &&
            ['blocked', 'thread_not_found'].contains(error.code)) {
          _invalidate(thread.otherUserId);
        }
      }
    } finally {
      if (!_disposed && generation == _historyGeneration) {
        _historyLoading = false;
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<bool> send(String text) async {
    final thread = _activeThread;
    final body = text.trim();
    if (_disposed ||
        thread == null ||
        unavailable ||
        _sending ||
        body.isEmpty ||
        text.length > 4000) {
      return false;
    }
    final random = Random.secure();
    final clientId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final pending = ChatMessage(
      id: 'local-$clientId',
      threadId: thread.id,
      senderId: userId,
      clientMessageId: clientId,
      body: body,
      moderationStatus: 'approved',
      createdAt: DateTime.now().toUtc(),
      delivery: MessageDelivery.sending,
    );
    _merge(pending);
    await _deliver(pending);
    return true;
  }

  Future<void> retry(String clientMessageId) async {
    if (_disposed || _sending || unavailable) {
      return;
    }
    final matches = messages.where(
      (m) =>
          m.clientMessageId == clientMessageId &&
          m.delivery == MessageDelivery.failed,
    );
    if (matches.isEmpty) {
      return;
    }
    await _deliver(matches.first.withDelivery(MessageDelivery.sending));
  }

  Future<void> _deliver(ChatMessage pending) async {
    _sending = true;
    _merge(pending);
    _notify();
    try {
      ChatMessage? delivered;
      if (_connected) {
        final completer = Completer<ChatMessage>();
        _ack = completer;
        _ackClientId = pending.clientMessageId;
        try {
          socket.send({
            'type': 'send',
            'thread_id': pending.threadId,
            'client_message_id': pending.clientMessageId,
            'body': pending.body,
          });
          delivered = await completer.future.timeout(ackTimeout);
        } catch (error) {
          // An ack can be lost after persistence. REST uses the SAME id.
          // Explicit server rejection must not be silently retried.
          if (error is ApiException) {
            rethrow;
          }
        } finally {
          _ack = null;
          _ackClientId = null;
        }
      }
      if (_disposed) {
        return;
      }
      delivered ??= await api.send(
        pending.threadId,
        pending.clientMessageId,
        pending.body,
      );
      if (_disposed) {
        return;
      }
      _merge(delivered);
      unawaited(refreshInbox());
    } catch (error) {
      if (!_disposed) {
        final description = _describe(error);
        // A late WS ack may have already resolved an uncertain REST response.
        final alreadySent = (_history[pending.threadId] ?? []).any(
          (m) =>
              m.clientMessageId == pending.clientMessageId &&
              m.delivery == MessageDelivery.sent,
        );
        if (!alreadySent) {
          _merge(
            pending.withDelivery(MessageDelivery.failed, error: description),
          );
        }
        if (error is ApiException &&
            error.code == 'blocked' &&
            _activeThread?.id == pending.threadId) {
          _invalidate(_activeThread!.otherUserId);
        }
      }
    } finally {
      _sending = false;
      _notify();
    }
  }

  void _merge(ChatMessage message) {
    if (_blockedThreads.contains(message.threadId)) {
      return;
    }
    final list = _history.putIfAbsent(message.threadId, () => []);
    list.removeWhere(
      (m) =>
          m.id == message.id ||
          (message.clientMessageId.isNotEmpty &&
              m.senderId == message.senderId &&
              m.clientMessageId == message.clientMessageId),
    );
    list.add(message);
    list.sort((a, b) {
      final time = b.createdAt.compareTo(a.createdAt);
      return time == 0 ? b.id.compareTo(a.id) : time;
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    if (_disposed || !_foreground) {
      return;
    }
    try {
      switch (event['type']) {
        case 'connected':
          _connected = true;
          _restartHydration();
          unawaited(refreshHistory());
          break;
        case 'disconnected':
          _connected = false;
          _restartHydration();
          break;
        case 'message':
        case 'ack':
          final message = ChatMessage.fromJson(
            event['message'] as Map<String, dynamic>,
          );
          _merge(message);
          if (message.senderId == userId &&
              message.clientMessageId == _ackClientId &&
              _ack?.isCompleted == false) {
            _ack!.complete(message);
          }
          if (_activeThread?.id == message.threadId) {
            _markRead();
          }
          unawaited(refreshInbox());
          break;
        case 'read_ack':
          unawaited(refreshInbox());
          break;
        case 'blocked':
          _invalidate(event['blocked_user_id'] as String);
          _connected = false;
          // The server closes all sockets for both users. Let unrelated
          // in-flight sends fall back to REST, which rechecks the exact pair.
          break;
        case 'error':
          if (_ack?.isCompleted == false) {
            _ack!.completeError(
              ApiException(
                statusCode: 400,
                code: event['code'] as String? ?? 'chat_error',
                message:
                    event['message'] as String? ?? 'Message could not be sent.',
              ),
            );
          }
          break;
      }
    } catch (_) {
      /* Ignore malformed server events, without logging content. */
    }
    _notify();
  }

  void _restartHydration() {
    _historyGeneration++;
    _historyLoading = false;
    _loadingMore = false;
    _historyReady = false;
  }

  void _markRead() {
    if (_connected &&
        _foreground &&
        _historyReady &&
        _activeThread != null &&
        !unavailable) {
      socket.send({'type': 'read', 'thread_id': _activeThread!.id});
    }
  }

  void _invalidate(String otherUserId) {
    _blockedUsers.add(otherUserId);
    for (final thread in _threads.where((t) => t.otherUserId == otherUserId)) {
      _blockedThreads.add(thread.id);
      _history.remove(thread.id);
    }
    if (_activeThread?.otherUserId == otherUserId) {
      _historyGeneration++;
      _historyLoading = false;
      _loadingMore = false;
      _historyReady = false;
      _blockedThreads.add(_activeThread!.id);
      _history.remove(_activeThread!.id);
      _historyError = 'This conversation is unavailable.';
    }
    _threads.removeWhere((t) => t.otherUserId == otherUserId);
    _notify();
  }

  String _describe(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        onSessionExpired?.call();
      }
      return error.message;
    }
    return 'Could not connect. Check your connection and try again.';
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    if (_ack?.isCompleted == false) {
      _ack!.completeError(StateError('Chat session ended.'));
    }
    unawaited(_subscription.cancel());
    socket.dispose();
    api.client.close();
    _history.clear();
    _threads.clear();
    super.dispose();
  }
}

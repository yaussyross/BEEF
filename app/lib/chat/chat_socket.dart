import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Native-only mobile transport: the token stays in an Authorization header,
/// never a URL, debug log, analytics event, or persisted message cache.
abstract class ChatSocket {
  Stream<Map<String, dynamic>> get events;
  Future<void> connect(String baseUrl, String token);
  void send(Map<String, dynamic> frame);
  Future<void> disconnect();
  void dispose();
}

class NativeChatSocket implements ChatSocket {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect(String baseUrl, String token) async {
    final disconnecting = disconnect();
    final generation = _generation;
    await disconnecting;
    if (generation != _generation || _events.isClosed) {
      return;
    }
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/api/ws',
      query: null,
      fragment: null,
    );
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 10),
      pingInterval: const Duration(seconds: 20),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      (dynamic raw) {
        if (generation != _generation || _events.isClosed) {
          return;
        }
        try {
          final dynamic data = jsonDecode(raw as String);
          if (data is Map<String, dynamic>) {
            _events.add(data);
          }
        } catch (_) {
          /* A malformed frame must not crash the chat UI. */
        }
      },
      onError: (Object _) => _disconnected(generation),
      onDone: () => _disconnected(generation),
    );
    await channel.ready;
    if (generation != _generation) {
      await channel.sink.close();
    }
  }

  void _disconnected(int generation) {
    if (generation == _generation && !_events.isClosed) {
      _events.add({'type': 'disconnected'});
    }
  }

  @override
  void send(Map<String, dynamic> frame) =>
      _channel?.sink.add(jsonEncode(frame));

  @override
  Future<void> disconnect() async {
    _generation++;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_events.close());
  }
}

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectNative(Uri uri, String token) => IOWebSocketChannel.connect(
  uri, headers: {'Authorization': 'Bearer $token'},
  connectTimeout: const Duration(seconds: 10),
  pingInterval: const Duration(seconds: 20),
);

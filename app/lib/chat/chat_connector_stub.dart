import 'package:web_socket_channel/web_socket_channel.dart';

// Browser previews use controlled fixtures. Never put bearer tokens in URLs.
WebSocketChannel connectNative(Uri uri, String token) =>
  throw UnsupportedError('Native chat transport is unavailable in this preview.');

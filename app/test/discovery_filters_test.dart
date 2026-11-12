import 'dart:async';
import 'dart:convert';
import 'package:beef/api/discovery_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/discovery/discovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'chat_test_helpers.dart';
void main() {
  test('late discovery response cannot replace a newer filter and dispose stops notifications', () async {
    final pending = <Completer<http.Response>>[];
    final client = ApiClient(baseUrl: 'https://example.test', tokenStore: MemoryTokens(),
      httpClient: MockClient((r) { final c = Completer<http.Response>(); pending.add(c); return c.future; }));
    final controller = DiscoveryController(api: DiscoveryApi(client));
    final old = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final fresh = controller.toggleInterest('hiking');
    await Future<void>.delayed(Duration.zero);
    http.Response rows(String id) => http.Response(jsonEncode({'items': [{'user_id': id, 'distance': 'nearby'}], 'has_more': false}), 200);
    pending[1].complete(rows('new')); await fresh;
    pending[0].complete(rows('old')); await old;
    expect(controller.items.single.userId, 'new');
    final last = controller.refresh(); await Future<void>.delayed(Duration.zero);
    controller.dispose(); pending[2].complete(rows('disposed')); await last;
  });
  test('selected interests reach discovery server and clearing removes filter', () async {
    final queries = <Map<String, String>>[];
    final client = ApiClient(baseUrl: 'https://example.test', tokenStore: MemoryTokens(),
      httpClient: MockClient((r) async {
        queries.add(r.url.queryParameters);
        return http.Response(jsonEncode({'items': [], 'has_more': false}), 200);
      }));
    final controller = DiscoveryController(api: DiscoveryApi(client));
    await controller.toggleInterest('hiking');
    expect(queries.last['interests'], 'hiking');
    await controller.clearInterestFilter();
    expect(queries.last.containsKey('interests'), false);
    controller.dispose();
  });
}

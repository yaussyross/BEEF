import 'dart:convert';
import 'package:beef/api/http_client.dart';
import 'package:beef/api/location_api.dart';
import 'package:beef/screens/test_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'chat_test_helpers.dart';
void main() {
  testWidgets('synthetic area requires explicit action, preserves preferences and retries failure', (tester) async {
    final sent = <Map<String, dynamic>>[];
    final client = ApiClient(baseUrl: 'https://example.test', tokenStore: MemoryTokens(),
      httpClient: MockClient((r) async {
        sent.add(jsonDecode(r.body) as Map<String, dynamic>);
        return sent.length == 1 ? http.Response('{"error":"unavailable"}', 503) : http.Response('{"ok":true}', 200);
      }));
    await tester.pumpWidget(MaterialApp(home: TestLocationScreen(api: LocationApi(client))));
    await tester.pumpAndSettle(); expect(sent, isEmpty);
    await tester.tap(find.text('Use test area')); await tester.pumpAndSettle();
    expect(find.text('Synthetic test area saved. Return to the grid to refresh.'), findsNothing);
    await tester.tap(find.text('Use test area')); await tester.pumpAndSettle();
    expect(sent, [{'lat': 37.7749, 'lng': -122.4194}, {'lat': 37.7749, 'lng': -122.4194}]);
    expect(find.text('Synthetic test area saved. Return to the grid to refresh.'), findsOneWidget);
    client.close();
  });
}

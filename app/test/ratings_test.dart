import 'dart:async';
import 'dart:convert';

import 'package:beef/api/http_client.dart';
import 'package:beef/api/ratings_api.dart';
import 'package:beef/screens/rating_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(baseUrl: 'https://example.test', tokenStore: MemoryTokens(),
      httpClient: MockClient(handler));

Widget screen(ApiClient client) => MaterialApp(
  home: RatingScreen(userId: 'other', api: RatingsApi(client)),
);

void main() {
  test('rating API sends only stars and authenticates using a header', () async {
    final transport = client((request) async {
      expect(request.url.path, '/api/ratings/other');
      expect(request.headers['Authorization'], 'Bearer test-access');
      expect(request.url.query, isEmpty);
      if (request.method == 'GET') {
        return response({'eligible': true, 'my_rating': 2});
      }
      expect(jsonDecode(request.body), {'stars': 5});
      return response({'rating': {'stars': 5}});
    });
    final api = RatingsApi(transport);
    expect((await api.eligibility('other')).myRating, 2);
    expect(await api.save('other', 5), 5);
    await expectLater(api.save('other', 0), throwsArgumentError);
    transport.close();
  });

  testWidgets('locked ratings need a new server check, not a client timer', (tester) async {
    var eligible = false;
    final transport = client((request) async =>
      response({'eligible': eligible, 'my_rating': null}));
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leaving chat open does not count.'), findsOneWidget);
    expect(find.byTooltip('5 stars'), findsNothing);
    eligible = true;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('5 stars'), findsOneWidget);
    transport.close();
  });

  testWidgets('load failure can retry without exposing a rating form', (tester) async {
    var offline = true;
    final transport = client((request) async {
      if (offline) throw http.ClientException('offline');
      return response({'eligible': true, 'my_rating': 3});
    });
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    expect(find.text('Could not check rating eligibility. Try again.'), findsOneWidget);
    expect(find.byTooltip('3 stars'), findsNothing);
    offline = false;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Update rating'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    transport.close();
  });

  testWidgets('failed save preserves selection; retry confirms and permits re-rating', (tester) async {
    var attempts = 0;
    final transport = client((request) async {
      if (request.method == 'GET') return response({'eligible': true, 'my_rating': null});
      attempts++;
      expect(jsonDecode(request.body), {'stars': 4});
      if (attempts == 1) throw http.ClientException('offline');
      return response({'rating': {'stars': 4}});
    });
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4 stars'));
    await tester.pump();
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();
    expect(find.text('Could not confirm your rating. Try again.'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();
    expect(find.text('Your rating was saved.'), findsOneWidget);
    expect(find.text('Update rating'), findsOneWidget);
    expect(attempts, 2);
    transport.close();
  });

  testWidgets('double submit is guarded while a save is in flight', (tester) async {
    final pending = Completer<http.Response>();
    var saves = 0;
    final transport = client((request) async {
      if (request.method == 'GET') return response({'eligible': true, 'my_rating': null});
      saves++;
      return pending.future;
    });
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('2 stars'));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(saves, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.complete(response({'rating': {'stars': 2}}));
    await tester.pumpAndSettle();
    transport.close();
  });

  for (final entry in {'rating_not_eligible': 403, 'account_disabled': 403, 'user_not_found': 404}.entries) {
    testWidgets('server ${entry.key} removes controls and never claims success', (tester) async {
    final transport = client((request) async {
      if (request.method == 'GET') return response({'eligible': true, 'my_rating': null});
      return response({'error': entry.key, 'message': 'Rating unavailable.'}, entry.value);
    });
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pump();
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();
    expect(find.text('Rating unavailable.'), findsOneWidget);
    expect(find.text('Your rating was saved.'), findsNothing);
    expect(find.byTooltip('5 stars'), findsNothing);
    transport.close();
  });

  }

  testWidgets('rating controls fit a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = client((request) async => response({'eligible': true, 'my_rating': null}));
    await tester.pumpWidget(screen(transport));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    transport.close();
  });
}

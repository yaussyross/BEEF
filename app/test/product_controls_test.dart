import 'dart:convert';
import 'package:beef/api/http_client.dart';
import 'package:beef/api/safety_api.dart';
import 'package:beef/screens/blocked_users_screen.dart';
import 'package:beef/screens/edit_profile_screen.dart';
import 'package:beef/api/profile_api.dart';
import 'package:beef/screens/safety_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'chat_test_helpers.dart';

ApiClient clientFor(Future<http.Response> Function(http.Request) handler) => ApiClient(
  baseUrl: 'https://example.test', tokenStore: MemoryTokens(), httpClient: MockClient(handler));
http.Response reply(Object data, [int code = 200]) => http.Response(jsonEncode(data), code);

void main() {
  testWidgets('writing starters remain editable drafts until explicit profile save', (tester) async {
    final saved = <Map>[];
    final client = clientFor((r) async {
      if (r.method == 'GET') return reply({'user': {'id': 'self', 'bio': 'Coffee walks', 'intent_tags': [], 'interests': []}});
      final body = jsonDecode(r.body) as Map; saved.add(body);
      return reply({'user': {'id': 'self', ...body}});
    });
    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(api: ProfileApi(client))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ask me about:'));
    await tester.tap(find.text('Ask me about:')); await tester.pump();
    expect(saved, isEmpty);
    final editor = tester.widget<TextField>(find.widgetWithText(TextField, 'About me'));
    expect(editor.controller!.text, 'Coffee walks\n\nAsk me about: ');
    await tester.enterText(find.widgetWithText(TextField, 'About me'), 'Ask me about: board games');
    await tester.scrollUntilVisible(find.text('Save profile'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save profile')); await tester.pumpAndSettle();
    expect(saved.single['bio'], 'Ask me about: board games');
    expect(saved.single.keys.toSet(), {'display_name', 'bio', 'intent_tags', 'interests'});
    client.close();
  });

  testWidgets('message report retries retain only the exact message target', (tester) async {
    final bodies = <String>[];
    final client = clientFor((r) async {
      bodies.add(r.body);
      return bodies.length == 1 ? reply({'error': 'unavailable'}, 503)
        : reply({'ok': true, 'report_id': 'receipt'});
    });
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(userId: 'other', threadId: 'thread',
      messageId: 'message', api: SafetyApi(client))));
    tester.widget<DropdownButton<ReportKind>>(find.byType(DropdownButton<ReportKind>)).onChanged!(ReportKind.other);
    await tester.pump();
    await tester.tap(find.text('Submit report')); await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report')); await tester.pumpAndSettle();
    expect(bodies.length, 2); expect(bodies[1], bodies[0]);
    final body = jsonDecode(bodies[0]) as Map;
    expect(body['message_id'], 'message');
    expect(body.containsKey('thread_id'), false);
    expect(body.containsKey('reported_user_id'), false);
    expect(find.text('Your report was received for review.'), findsOneWidget);
    client.close();
  });

  testWidgets('unblock requires confirmation and survives failed request', (tester) async {
    var calls = 0;
    final client = clientFor((r) async {
      if (r.method == 'GET') return reply({'users': [{'user_id': 'fixture', 'blocked_at': '2026-01-01T00:00:00Z'}]});
      expect(jsonDecode(r.body), {'blocked_user_id': 'fixture'});
      calls++;
      return calls == 1 ? reply({'error': 'unavailable'}, 503) : reply({'ok': true, 'blocked': false});
    });
    await tester.pumpWidget(MaterialApp(home: BlockedUsersScreen(api: SafetyApi(client))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock')); await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(calls, 0);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Unblock')); await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm unblock')); await tester.pumpAndSettle();
    }
    expect(calls, 2); expect(find.text('No blocked users.'), findsOneWidget);
    client.close();
  });

  testWidgets('profile editor retries without losing draft and saves editable fields only', (tester) async {
    var saves = 0;
    final client = clientFor((r) async {
      if (r.method == 'GET') return reply({'user': {'id': 'self', 'display_name': 'Fixture', 'bio': '', 'intent_tags': [], 'interests': []}});
      final body = jsonDecode(r.body) as Map;
      expect(body.keys.toSet(), {'display_name', 'bio', 'intent_tags', 'interests'});
      expect(body['bio'], 'Coffee walks');
      saves++;
      return saves == 1 ? reply({'error': 'unavailable'}, 503) : reply({'user': {'id': 'self', ...body}});
    });
    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(api: ProfileApi(client))));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'About me'), 'Coffee walks');
    await tester.scrollUntilVisible(find.text('Save profile'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save profile')); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'About me')).controller!.text, 'Coffee walks');
    await tester.tap(find.text('Save profile')); await tester.pumpAndSettle();
    expect(saves, 2); expect(find.text('Profile saved.'), findsOneWidget);
    client.close();
  });
}

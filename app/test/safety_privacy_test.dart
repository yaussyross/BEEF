import 'dart:async';
import 'dart:convert';

import 'package:beef/api/http_client.dart';
import 'package:beef/api/chat_api.dart';
import 'package:beef/api/privacy_api.dart';
import 'package:beef/api/safety_api.dart';
import 'package:beef/chat/chat_controller.dart';
import 'package:beef/models/chat_message.dart';
import 'package:beef/screens/privacy_screen.dart';
import 'package:beef/screens/safety_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'chat_test_helpers.dart';

http.Response reply(Object data, [int status = 200]) => http.Response(jsonEncode(data), status);
ApiClient makeClient(Future<http.Response> Function(http.Request) handler) => ApiClient(
  baseUrl: 'https://example.test', tokenStore: MemoryTokens(), httpClient: MockClient(handler));

void main() {
  test('report IDs are independent UUIDs with secure random version and variant', () {
    final ids = List.generate(32, (_) => SafetyApi.newReportId());
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), true);
    }
  });

  testWidgets('unconfirmed response retries the identical report identity and payload', (tester) async {
    final requests = <String>[];
    final client = makeClient((request) async {
      requests.add(request.body);
      return requests.length == 1 ? reply({'ok': true})
        : reply({'ok': true, 'report_id': 'synthetic-confirmed'});
    });
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(userId: 'other', api: SafetyApi(client))));
    await tester.pumpAndSettle();
    tester.widget<DropdownButton<ReportKind>>(find.byType(DropdownButton<ReportKind>)).onChanged!(ReportKind.other);
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Your report was received for review.'), findsNothing);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(requests[1], requests[0]);
    expect(find.text('Your report was received for review.'), findsOneWidget);
    client.close();
  });

  test('safety requests use existing categories, scoped targets and bearer auth', () async {
    final requests = <http.Request>[];
    final client = makeClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer test-access');
      return reply(request.url.path == '/api/block'
        ? {'ok': true, 'blocked': true} : {'ok': true, 'report_id': 'synthetic-report'});
    });
    final api = SafetyApi(client);
    await api.block('other');
    await api.report('other', ReportKind.harassment, ' concern ', clientReportId: 'key-a');
    await api.report('other', ReportKind.other, '', clientReportId: 'key-b', threadId: 'thread-a');
    expect(jsonDecode(requests[0].body), {'blocked_user_id': 'other'});
    expect(jsonDecode(requests[1].body), {'client_report_id': 'key-a', 'reported_user_id': 'other', 'report_type': 'harassment', 'reason': 'concern'});
    expect(jsonDecode(requests[2].body), {'client_report_id': 'key-b', 'thread_id': 'thread-a', 'report_type': 'other', 'reason': ''});
    client.close();
  });

  test('privacy sends only preferences and rejects unknown modes', () async {
    final client = makeClient((request) async {
      if (request.method == 'PUT') expect(jsonDecode(request.body), {'coarse_location': 'region', 'hide_distance': true});
      return reply({'user': {'coarse_location': 'region', 'hide_distance': true,
        'birthdate': '1990-01-01', 'email': 'fictional@example.test'}});
    });
    final api = PrivacyApi(client);
    expect((await api.load()).mode, 'region');
    expect((await api.save('region', true)).hideDistance, true);
    expect(() => PrivacySettings.fromJson({'coarse_location': 'unknown', 'hide_distance': false}), throwsFormatException);
    client.close();
  });

  testWidgets('block needs confirmation and confirmed API success', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    bool? result;
    final client = makeClient((request) async { calls++; return pending.future; });
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      child: const Text('Open safety'),
      onPressed: () async { result = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => SafetyScreen(userId: 'other', api: SafetyApi(client)))); },
    ))));
    await tester.tap(find.text('Open safety'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(result, isNull);
    pending.complete(reply({'ok': true, 'blocked': true}));
    await tester.pumpAndSettle();
    expect(result, true);
    client.close();
  });

  testWidgets('report retry retains reason and category', (tester) async {
    var calls = 0;
    String? requestId;
    final client = makeClient((request) async {
      calls++;
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      requestId ??= data['client_report_id'] as String;
      expect(data, {'client_report_id': requestId, 'reported_user_id': 'other', 'report_type': 'harassment', 'reason': 'Test concern'});
      if (calls == 1) throw http.ClientException('offline');
      return reply({'ok': true, 'report_id': 'synthetic-report'}, 201);
    });
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(userId: 'other', api: SafetyApi(client))));
    await tester.pumpAndSettle();
    tester.widget<DropdownButton<ReportKind>>(find.byType(DropdownButton<ReportKind>)).onChanged!(ReportKind.harassment);
    await tester.enterText(find.byType(TextField), 'Test concern');
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Could not confirm your report. You can try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Test concern');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(tester.widget<DropdownButton<ReportKind>>(find.byType(DropdownButton<ReportKind>)).onChanged, isNull);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Your report was received for review.'), findsOneWidget);
    expect(find.text('Submit report'), findsNothing);
    expect(calls, 2);
    client.close();
  });

  testWidgets('suspended account cannot keep submitting reports', (tester) async {
    final client = makeClient((request) async => reply({'error': 'account_disabled', 'message': 'Account disabled.'}, 403));
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(userId: 'other', api: SafetyApi(client))));
    await tester.pumpAndSettle();
    tester.widget<DropdownButton<ReportKind>>(find.byType(DropdownButton<ReportKind>)).onChanged!(ReportKind.other);
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Account disabled.'), findsOneWidget);
    expect(find.text('Your report was received for review.'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    client.close();
  });

  testWidgets('privacy retry preserves changes and confirms successful save', (tester) async {
    var saves = 0;
    final client = makeClient((request) async {
      if (request.method == 'GET') return reply({'user': {'coarse_location': 'region', 'hide_distance': false}});
      saves++;
      expect(jsonDecode(request.body), {'coarse_location': 'region', 'hide_distance': true});
      if (saves == 1) throw http.ClientException('offline');
      return reply({'user': {'coarse_location': 'region', 'hide_distance': true}});
    });
    await tester.pumpWidget(MaterialApp(home: PrivacyScreen(api: PrivacyApi(client))));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value, 'region');
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(true);
    await tester.pump();
    await tester.tap(find.text('Save privacy settings'));
    await tester.pumpAndSettle();
    expect(find.text('Could not confirm your changes. Try again.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
    await tester.tap(find.text('Save privacy settings'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy settings saved.'), findsOneWidget);
    client.close();
  });

  testWidgets('privacy load failure never invents defaults', (tester) async {
    var load = 0;
    final client = makeClient((request) async {
      if (load++ == 0) throw http.ClientException('offline');
      return reply({'user': {'coarse_location': 'city', 'hide_distance': true}});
    });
    await tester.pumpWidget(MaterialApp(home: PrivacyScreen(api: PrivacyApi(client))));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
    client.close();
  });

  testWidgets('suspended privacy save disables controls without false success', (tester) async {
    final client = makeClient((request) async => request.method == 'GET'
      ? reply({'user': {'coarse_location': 'city', 'hide_distance': true}})
      : reply({'error': 'account_disabled', 'message': 'Account disabled.'}, 403));
    await tester.pumpWidget(MaterialApp(home: PrivacyScreen(api: PrivacyApi(client))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save privacy settings'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy settings saved.'), findsNothing);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
    client.close();
  });

  test('confirmed block clears local chat without a socket notification', () async {
    final api = FakeChatApi();
    api.onHistory = (_, __) async => ChatHistory([ChatMessage.fromJson(messageJson())], null);
    final chat = ChatController(api: api, userId: 'me', socket: FakeChatSocket());
    await chat.refreshInbox();
    await chat.openThread(testThread);
    expect(chat.messages, isNotEmpty);
    expect(chat.threads, isNotEmpty);
    chat.confirmBlock('other');
    expect(chat.unavailable, true);
    expect(chat.messages, isEmpty);
    expect(chat.threads.where((thread) => thread.otherUserId == 'other'), isEmpty);
    chat.dispose();
  });

  test('suspended chat response requests session teardown', () async {
    final api = FakeChatApi();
    api.onHistory = (_, __) async => throw const ApiException(
      statusCode: 403, code: 'account_disabled', message: 'Account disabled.');
    var expired = false;
    final chat = ChatController(api: api, userId: 'me', socket: FakeChatSocket(),
      onSessionExpired: () { expired = true; });
    await chat.openThread(testThread);
    expect(expired, true);
    chat.dispose();
  });

  testWidgets('privacy loading has no editable defaults', (tester) async {
    final pending = Completer<http.Response>();
    final client = makeClient((request) => pending.future);
    await tester.pumpWidget(MaterialApp(home: PrivacyScreen(api: PrivacyApi(client))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    pending.complete(reply({'user': {'coarse_location': 'city', 'hide_distance': true}}));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    client.close();
  });

  testWidgets('failed block stays on the screen and permits explicit retry', (tester) async {
    var calls = 0;
    final client = makeClient((request) async { calls++; throw http.ClientException('offline'); });
    await tester.pumpWidget(MaterialApp(home: SafetyScreen(userId: 'other', api: SafetyApi(client))));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Could not block this user. Try again.'), findsOneWidget);
    }
    expect(calls, 2);
    client.close();
  });

}

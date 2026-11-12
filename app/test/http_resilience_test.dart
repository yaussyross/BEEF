import 'dart:async';
import 'package:beef/api/auth_api.dart';
import 'package:beef/api/http_client.dart';
import 'package:beef/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'chat_test_helpers.dart';

void main() {
  for (final status in [429, 500, 503, 200]) {
    test('refresh $status retains credentials and never replays mutation', () async {
      final store=MemoryTokens();
      await store.writeTokens(accessToken:'old',refreshToken:'refresh');
      var writes=0;
      final client=ApiClient(baseUrl:'https://example.invalid',tokenStore:store,httpClient:MockClient((r) async {
        if(r.url.path=='/api/refresh') return http.Response('{}',status);
        writes++; return http.Response('{}',401);
      }));
      addTearDown(client.close);
      await expectLater(client.post('/api/write'),throwsA(isA<ApiException>().having((e)=>e.code,'code','refresh_unavailable')));
      expect(await store.readAccessToken(),'old'); expect(writes,1);
    });
  }
  for (final status in [401,403]) {
    test('refresh $status clears rejected credentials', () async {
      final store=MemoryTokens();
      await store.writeTokens(accessToken:'old',refreshToken:'refresh');
      final client=ApiClient(baseUrl:'https://example.invalid',tokenStore:store,httpClient:MockClient((r) async => http.Response('{}',r.url.path=='/api/refresh'?status:401)));
      addTearDown(client.close);
      await expectLater(client.get('/api/me'),throwsA(isA<ApiException>()));
      expect(await store.readAccessToken(),isNull);
    });
  }
  test('late refresh timeout cannot replace credentials', () async {
    final store=MemoryTokens(); await store.writeTokens(accessToken:'old',refreshToken:'refresh');
    final late=Completer<http.Response>();
    final client=ApiClient(baseUrl:'https://example.invalid',tokenStore:store,requestTimeout:const Duration(milliseconds:10),httpClient:MockClient((r) async => r.url.path=='/api/refresh'?await late.future:http.Response('{}',401)));
    addTearDown(client.close);
    await expectLater(client.get('/api/me'),throwsA(isA<ApiException>()));
    late.complete(http.Response('{"accessToken":"late","refreshToken":"late"}',200));
    await Future<void>.delayed(const Duration(milliseconds:20));
    expect(await store.readAccessToken(),'old');
  });
  test('ordinary mutation times out without retry', () async {
    var calls=0;
    final client=ApiClient(baseUrl:'https://example.invalid',tokenStore:MemoryTokens(),requestTimeout:const Duration(milliseconds:10),httpClient:MockClient((r) {calls++; return Completer<http.Response>().future;}));
    addTearDown(client.close);
    await expectLater(client.post('/api/write',authenticated:false),throwsA(isA<TimeoutException>()));
    expect(calls,1);
  });
  test('restore service failure preserves credentials without authenticating', () async {
    final store=MemoryTokens(); await store.writeTokens(accessToken:'old',refreshToken:'refresh');
    final client=ApiClient(baseUrl:'https://example.invalid',tokenStore:store,httpClient:MockClient((r) async=>http.Response('{}',503)));
    final auth=AuthController(api:AuthApi(client),tokenStore:store);
    addTearDown(auth.dispose); addTearDown(client.close);
    await auth.restore();
    expect(auth.isAuthenticated,isFalse); expect(auth.profile,isNull);
    expect(await store.readAccessToken(),'old');
  });
}

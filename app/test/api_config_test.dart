import 'package:beef/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('test target requires explicit HTTPS origin without credentials or tokens', () {
    expect(ApiConfig.isValid('https://example.test'), true);
    for (final value in ['', 'http://example.test', 'https://user:pass@example.test',
      'https://example.test?token=secret', 'https://example.test/path', 'not a URL']) {
      expect(ApiConfig.isValid(value), false, reason: value);
    }
  });
}

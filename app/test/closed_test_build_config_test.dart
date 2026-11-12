import 'package:beef/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const configured = bool.fromEnvironment('BEEF_EXPECT_CLOSED_TEST_BUILD');
  test('compiled closed-test configuration has the pinned origin and no device GPS', () {
    if (!configured) return;
    expect(ApiConfig.baseUrl, 'https://beef-synthetic-staging.onrender.com');
    expect(ApiConfig.isConfigured, true);
    expect(ApiConfig.deviceLocationEnabled, false);
  });
}

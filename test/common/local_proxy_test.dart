import 'package:fl_clash/common/local_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated credentials are safe for core authentication', () {
    final credentials = LocalProxyCredentials.generate();

    expect(credentials.username, 'flclash-android');
    expect(credentials.password.length, 32);
    expect(credentials.password, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(
      credentials.coreAuthentication,
      'flclash-android:${credentials.password}',
    );
  });

  test(
    'Android authentication replaces imported authentication without mutating input',
    () {
      const credentials = LocalProxyCredentials(
        username: 'flclash-android',
        password: 'test-password',
      );
      const rawConfig = <String, dynamic>{
        'authentication': ['old-user:old-password'],
        'mixed-port': 7890,
      };

      final patched = applyAndroidLocalProxyAuthentication(
        rawConfig: rawConfig,
        credentials: credentials,
      );

      expect(patched['authentication'], ['flclash-android:test-password']);
      expect(rawConfig['authentication'], ['old-user:old-password']);
      expect(patched['mixed-port'], 7890);
    },
  );

  test('only Android disables the unsupported system proxy path', () {
    expect(shouldUseSystemProxy(isAndroid: true, requested: true), isFalse);
    expect(shouldUseSystemProxy(isAndroid: true, requested: false), isFalse);
    expect(shouldUseSystemProxy(isAndroid: false, requested: true), isTrue);
    expect(shouldUseSystemProxy(isAndroid: false, requested: false), isFalse);
  });

  test('proxy credentials are limited to the current local endpoint', () {
    expect(isLocalProxyEndpoint('localhost', 7890, 7890), isTrue);
    expect(isLocalProxyEndpoint('127.0.0.1', 7890, 7890), isTrue);
    expect(isLocalProxyEndpoint('10.0.0.2', 7890, 7890), isFalse);
    expect(isLocalProxyEndpoint('localhost', 7891, 7890), isFalse);
  });
}

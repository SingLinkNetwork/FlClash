import 'dart:io';

import 'package:fl_clash/common/http.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  late ProviderContainer container;
  late HttpServer server;

  setUpAll(() async {
    container = ProviderContainer();
    globalState.container = container;
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/tls/localhost-cert.pem')
      ..usePrivateKey('test/fixtures/tls/localhost-key.pem');
    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) => request.response.close());
  });

  setUp(() {
    container.read(runTimeProvider.notifier).update((_) => null);
  });

  tearDownAll(() {
    container.dispose();
    return server.close(force: true);
  });

  test('HTTP overrides reject an untrusted TLS certificate', () async {
    final client = FlClashHttpOverrides().createHttpClient(null);
    addTearDown(client.close);

    final request = client.getUrl(
      Uri(scheme: 'https', host: '127.0.0.1', port: server.port),
    );

    await expectLater(request, throwsA(isA<HandshakeException>()));
  });

  test('HTTP overrides preserve proxy routing for active connections', () {
    container.read(runTimeProvider.notifier).update((_) => 1);
    final mixedPort = container.read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );

    expect(
      FlClashHttpOverrides.handleFindProxy(Uri.parse('https://example.com')),
      'PROXY localhost:$mixedPort',
    );
    expect(
      FlClashHttpOverrides.handleFindProxy(Uri.parse('https://localhost')),
      'DIRECT',
    );
    expect(
      FlClashHttpOverrides.handleFindProxy(Uri.parse('https://127.0.0.1')),
      'DIRECT',
    );
    expect(
      FlClashHttpOverrides.handleFindProxy(Uri.parse('https://[::1]')),
      'DIRECT',
    );
  });
}

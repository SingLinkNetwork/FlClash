import 'dart:io';

import 'package:fl_clash/common/http.dart';
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

  tearDownAll(() {
    container.dispose();
    return server.close(force: true);
  });

  test('HTTP overrides reject an untrusted TLS certificate', () async {
    final client = FlClashHttpOverrides().createHttpClient(null);
    addTearDown(client.close);

    final request = client.getUrl(
      Uri(scheme: 'https', host: 'localhost', port: server.port),
    );

    await expectLater(request, throwsA(isA<HandshakeException>()));
  });
}

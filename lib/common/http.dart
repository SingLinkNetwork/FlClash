import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void configureLocalProxyAuthentication(HttpClient client) {
  if (!system.isAndroid) return;
  client.authenticateProxy = (host, port, scheme, realm) async {
    final mixedPort = globalState.container.read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    if (!isLocalProxyEndpoint(host, port, mixedPort) ||
        scheme.toLowerCase() != 'basic') {
      return false;
    }
    final credentials = globalState.localProxyCredentials;
    client.addProxyCredentials(
      host,
      port,
      realm ?? '',
      HttpClientBasicCredentials(credentials.username, credentials.password),
    );
    return true;
  };
}

class FlClashHttpOverrides extends HttpOverrides {
  static bool _isLoopbackHost(String host) {
    return host == 'localhost' ||
        InternetAddress.tryParse(host)?.isLoopback == true;
  }

  static String handleFindProxy(Uri url) {
    if (_isLoopbackHost(url.host)) {
      return 'DIRECT';
    }
    final ref = globalState.container;
    final isStart = ref.read(isStartProvider);
    final suspend = ref.read(suspendProvider);
    commonPrint.log('find $url proxy: $isStart');
    if (!isStart || suspend) return 'DIRECT';
    final mixedPort = ref.read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return 'PROXY localhost:$mixedPort';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = handleFindProxy;
    configureLocalProxyAuthentication(client);
    return client;
  }
}

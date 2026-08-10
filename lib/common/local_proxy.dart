import 'dart:math';

const _localProxyUsername = 'flclash-android';
const _localProxyPasswordAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
const _localProxyPasswordLength = 32;

class LocalProxyCredentials {
  final String username;
  final String password;

  const LocalProxyCredentials({required this.username, required this.password});

  factory LocalProxyCredentials.generate() {
    final random = Random.secure();
    final password = List.generate(
      _localProxyPasswordLength,
      (_) =>
          _localProxyPasswordAlphabet[random.nextInt(
            _localProxyPasswordAlphabet.length,
          )],
    ).join();
    return LocalProxyCredentials(
      username: _localProxyUsername,
      password: password,
    );
  }

  String get coreAuthentication => '$username:$password';
}

Map<String, dynamic> applyAndroidLocalProxyAuthentication({
  required Map<String, dynamic> rawConfig,
  required LocalProxyCredentials credentials,
}) {
  final patchedConfig = Map<String, dynamic>.from(rawConfig);
  patchedConfig['authentication'] = [credentials.coreAuthentication];
  return patchedConfig;
}

bool shouldUseSystemProxy({required bool isAndroid, required bool requested}) {
  return requested && !isAndroid;
}

bool isLocalProxyEndpoint(String host, int port, int expectedPort) {
  return (host == 'localhost' || host == '127.0.0.1') && port == expectedPort;
}

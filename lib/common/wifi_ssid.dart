typedef WifiSsidReader = Future<String?> Function();

Future<String?> readWifiSsidIfAllowed({
  required Future<bool> Function() isAllowed,
  required WifiSsidReader read,
}) async {
  if (!await isAllowed()) return null;
  return read();
}

class WifiSsidReadCoordinator {
  final WifiSsidReader read;
  final void Function(String? ssid) onRead;
  final Duration timeout;

  int _generation = 0;
  bool _disposed = false;

  WifiSsidReadCoordinator({
    required this.read,
    required this.onRead,
    this.timeout = const Duration(seconds: 1),
  });

  Future<void> refresh() async {
    final generation = ++_generation;
    String? ssid;
    try {
      ssid = await read().timeout(timeout);
    } catch (_) {
      ssid = null;
    }

    if (_disposed || generation != _generation) return;
    onRead(ssid);
  }

  void invalidate() {
    _generation++;
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}

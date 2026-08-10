import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

typedef WifiSsidReader = Future<String?> Function();
typedef WifiConnectivityReader = Future<List<ConnectivityResult>> Function();

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

class WifiSsidConnectivityCoordinator {
  final WifiConnectivityReader checkConnectivity;
  final WifiSsidReadCoordinator _ssidReadCoordinator;

  int _connectivityGeneration = 0;
  bool _disposed = false;
  List<String> _excludedSsids = const [];

  WifiSsidConnectivityCoordinator({
    required this.checkConnectivity,
    required WifiSsidReader read,
    required void Function(String? ssid) onRead,
    Duration timeout = const Duration(seconds: 1),
  }) : _ssidReadCoordinator = WifiSsidReadCoordinator(
         read: read,
         onRead: onRead,
         timeout: timeout,
       );

  Future<void> refreshCurrentConnectivity() async {
    final generation = ++_connectivityGeneration;
    List<ConnectivityResult> results;
    try {
      results = await checkConnectivity();
    } catch (_) {
      if (_disposed || generation != _connectivityGeneration) return;
      await _applyConnectivity(const []);
      return;
    }

    if (_disposed || generation != _connectivityGeneration) return;
    await _applyConnectivity(results);
  }

  void handleConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) return;
    _connectivityGeneration++;
    unawaited(_applyConnectivity(results));
  }

  void updateExcludedSsids(List<String> ssids) {
    if (_sameList(_excludedSsids, ssids)) return;
    _excludedSsids = List.unmodifiable(ssids);
    if (_excludedSsids.isNotEmpty) {
      unawaited(refreshCurrentConnectivity());
    }
  }

  Future<void> _applyConnectivity(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.wifi)) {
      await _ssidReadCoordinator.refresh();
      return;
    }
    _ssidReadCoordinator.invalidate();
    _ssidReadCoordinator.onRead(null);
  }

  bool _sameList(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void dispose() {
    _disposed = true;
    _connectivityGeneration++;
    _ssidReadCoordinator.dispose();
  }
}

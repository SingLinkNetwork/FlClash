import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

class ConnectivityManager extends ConsumerStatefulWidget {
  final Function(List<ConnectivityResult> results)? onConnectivityChanged;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    required this.child,
  });

  @override
  ConsumerState<ConnectivityManager> createState() =>
      _ConnectivityManagerState();
}

class _ConnectivityManagerState extends ConsumerState<ConnectivityManager> {
  late final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> subscription;
  late final WifiSsidConnectivityCoordinator _ssidConnectivityCoordinator;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _ssidConnectivityCoordinator = WifiSsidConnectivityCoordinator(
      checkConnectivity: _connectivity.checkConnectivity,
      read: () => readWifiSsidIfAllowed(
        isAllowed: () async {
          final permission = await WifiSsidManager.instance.checkPermission();
          if (supportsSsidLocationPermissions(
            isAndroid: system.isAndroid,
            isMacOS: system.isMacOS,
            isWindows: system.isWindows,
          )) {
            globalState.container
                    .read(locationPermissionsProvider.notifier)
                    .value =
                permission;
          }
          return permission == WifiSsidPermission.granted;
        },
        read: WifiSsidManager.instance.getSsid,
      ),
      onRead: (ssid) {
        globalState.container.read(currentSSIDProvider.notifier).value = ssid;
        commonPrint.log('Wi-fi SSID: $ssid ', logLevel: LogLevel.info);
      },
    );
    subscription = _connectivity.onConnectivityChanged.listen((results) {
      _ssidConnectivityCoordinator.handleConnectivityChanged(results);
      if (widget.onConnectivityChanged != null) {
        widget.onConnectivityChanged!(results);
      }
    });
    ref.listenManual(excludeSSIDsProvider, (previous, next) {
      if (previous != next) {
        _ssidConnectivityCoordinator.updateExcludedSsids(next);
      }
    });
    ref.listenManual(locationPermissionsProvider, (previous, next) {
      if (previous != next && next == WifiSsidPermission.granted) {
        unawaited(_ssidConnectivityCoordinator.refreshCurrentConnectivity());
      }
    });

    final excludedSsids = ref.read(excludeSSIDsProvider);
    _ssidConnectivityCoordinator.updateExcludedSsids(excludedSsids);
    if (excludedSsids.isEmpty) {
      unawaited(_ssidConnectivityCoordinator.refreshCurrentConnectivity());
    }
  }

  @override
  void dispose() {
    _ssidConnectivityCoordinator.dispose();
    unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

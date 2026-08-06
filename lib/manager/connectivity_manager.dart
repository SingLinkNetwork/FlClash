import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

class ConnectivityManager extends StatefulWidget {
  final Function(List<ConnectivityResult> results)? onConnectivityChanged;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    required this.child,
  });

  @override
  State<ConnectivityManager> createState() => _ConnectivityManagerState();
}

class _ConnectivityManagerState extends State<ConnectivityManager> {
  late final StreamSubscription<List<ConnectivityResult>> subscription;
  late final WifiSsidReadCoordinator _ssidReadCoordinator;

  @override
  void initState() {
    super.initState();
    _ssidReadCoordinator = WifiSsidReadCoordinator(
      read: () => readWifiSsidIfAllowed(
        isAllowed: () async {
          final permission = await WifiSsidManager.instance.checkPermission();
          return permission == WifiSsidPermission.granted;
        },
        read: WifiSsidManager.instance.getSsid,
      ),
      onRead: (ssid) {
        globalState.container.read(currentSSIDProvider.notifier).value = ssid;
        commonPrint.log('Wi-fi SSID: $ssid ', logLevel: LogLevel.info);
      },
    );
    subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.wifi)) {
        unawaited(_ssidReadCoordinator.refresh());
      } else {
        _ssidReadCoordinator.invalidate();
        globalState.container.read(currentSSIDProvider.notifier).value = null;
      }
      if (widget.onConnectivityChanged != null) {
        widget.onConnectivityChanged!(results);
      }
    });
  }

  @override
  void dispose() {
    _ssidReadCoordinator.dispose();
    unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

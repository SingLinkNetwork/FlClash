import 'package:fl_clash/common/permission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_ssid/wifi_ssid_manager.dart';

void main() {
  group('supportsSsidLocationPermissions', () {
    test(
      'includes Windows because its WLAN API can require location access',
      () {
        expect(
          supportsSsidLocationPermissions(
            isAndroid: false,
            isMacOS: false,
            isWindows: true,
          ),
          isTrue,
        );
      },
    );

    test('does not enable a location permission entry on Linux', () {
      expect(
        supportsSsidLocationPermissions(
          isAndroid: false,
          isMacOS: false,
          isWindows: false,
        ),
        isFalse,
      );
    });
  });

  group('getLocationPermissionFollowUp', () {
    test('does nothing after location access is granted', () {
      expect(
        getLocationPermissionFollowUp(WifiSsidPermission.granted),
        LocationPermissionFollowUp.none,
      );
    });

    test('opens settings only after a permanent denial', () {
      expect(
        getLocationPermissionFollowUp(WifiSsidPermission.denied),
        LocationPermissionFollowUp.showDeniedMessage,
      );
      expect(
        getLocationPermissionFollowUp(WifiSsidPermission.permanentlyDenied),
        LocationPermissionFollowUp.openSettings,
      );
    });
  });
}

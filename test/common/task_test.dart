import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile ipv6 value wins over the client fallback', () {
    final result = applyCorePatchConfig(
      rawConfig: {'ipv6': true, 'ip-version': 'ipv6-prefer'},
      patchConfig: const PatchClashConfig(ipv6: false),
    );

    expect(result['ipv6'], true);
    expect(result['ip-version'], 'ipv6-prefer');
  });

  test('client ipv6 setting is used when the profile omits ipv6', () {
    final result = applyCorePatchConfig(
      rawConfig: {'ip-version': 'ipv6-prefer'},
      patchConfig: const PatchClashConfig(ipv6: true),
    );

    expect(result['ipv6'], true);
    expect(result['ip-version'], 'ipv6-prefer');
  });

  test('profile ipv6 false also wins over the client fallback', () {
    final result = applyCorePatchConfig(
      rawConfig: {'ipv6': false},
      patchConfig: const PatchClashConfig(ipv6: true),
    );

    expect(result['ipv6'], false);
  });
}

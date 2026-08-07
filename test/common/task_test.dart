import 'dart:io';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy backup identifiers', () {
    test('normalizes string and numeric identifiers', () {
      expect(normalizeLegacyId('123'), '123');
      expect(normalizeLegacyId(123), '123');
      expect(normalizeLegacyId(123.0), '123');
    });

    test('rejects identifiers that cannot be used as file names', () {
      expect(normalizeLegacyId(null), isNull);
      expect(normalizeLegacyId(''), isNull);
      expect(normalizeLegacyId(1.5), isNull);
      expect(normalizeLegacyId(true), isNull);
    });
  });

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

  test('profile output writes recvmsgx only for macOS', () async {
    final profile = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/tmp/flclash-recvmsgx-test',
        profileId: 11,
        rawConfig: {},
        realPatchConfig: PatchClashConfig(tun: Tun(recvMsgX: false)),
        overrideDns: false,
        appendSystemDns: false,
        proxyGroups: [],
        rules: [],
        addedRules: [],
        defaultUA: 'FlClash-Test',
      ),
    );

    if (Platform.isMacOS) {
      expect(profile.a, contains('recvmsgx: false'));
    } else {
      expect(profile.a, isNot(contains('recvmsgx: false')));
    }
  });
}

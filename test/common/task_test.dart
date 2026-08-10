import 'dart:io';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/enum/enum.dart';
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

  test(
    'DNS overwrite does not append system DNS when the setting is disabled',
    () async {
      final profile = await makeRealProfileTask(
        const MakeRealProfileState(
          profilesPath: '/tmp/flclash-dns-overwrite-test',
          profileId: 13,
          rawConfig: {},
          realPatchConfig: PatchClashConfig(
            dns: Dns(nameserver: ['https://resolver.example/dns-query']),
          ),
          overrideDns: true,
          appendSystemDns: false,
          proxyGroups: [],
          rules: [],
          addedRules: [],
          defaultUA: 'FlClash-Test',
        ),
      );

      expect(profile.a, contains('https://resolver.example/dns-query'));
      expect(profile.a, isNot(contains('system://')));
    },
  );

  test('DNS appends system DNS only when the setting is enabled', () async {
    final profile = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/tmp/flclash-dns-system-test',
        profileId: 14,
        rawConfig: {},
        realPatchConfig: PatchClashConfig(
          dns: Dns(nameserver: ['https://resolver.example/dns-query']),
        ),
        overrideDns: true,
        appendSystemDns: true,
        proxyGroups: [],
        rules: [],
        addedRules: [],
        defaultUA: 'FlClash-Test',
      ),
    );

    expect(profile.a, contains('https://resolver.example/dns-query'));
    expect(profile.a, contains('system://'));
  });

  test(
    'profile GEO URLs survive when the app has no custom GEO URL override',
    () async {
      const profileGeoIpUrl = 'https://profile.example/geoip.dat';
      const profileGeoSiteUrl = 'https://profile.example/geosite.dat';
      final profile = await makeRealProfileTask(
        const MakeRealProfileState(
          profilesPath: '/tmp/flclash-geo-url-test',
          profileId: 12,
          rawConfig: {
            'geox-url': {
              'geoip': profileGeoIpUrl,
              'geosite': profileGeoSiteUrl,
            },
          },
          realPatchConfig: PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: [],
          rules: [],
          addedRules: [],
          defaultUA: 'FlClash-Test',
        ),
      );

      expect(profile.a, contains('geoip: "$profileGeoIpUrl"'));
      expect(profile.a, contains('geosite: "$profileGeoSiteUrl"'));
    },
  );

  test('custom app GEO URL overrides the profile GEO URL', () {
    const appGeoIpUrl = 'https://app.example/geoip.dat';
    final urls = resolveGeoXUrls(
      rawConfig: {
        'geox-url': {'geoip': 'https://profile.example/geoip.dat'},
      },
      patchConfig: const PatchClashConfig(
        geoXUrl: {GeoResource.GEOIP: appGeoIpUrl},
      ),
    );

    expect(urls['geoip'], appGeoIpUrl);
  });

  test(
    'partial app GEO settings retain defaults for unspecified resources',
    () {
      const appGeoIpUrl = 'https://app.example/geoip.dat';
      final urls = resolveGeoXUrls(
        rawConfig: const {},
        patchConfig: const PatchClashConfig(
          geoXUrl: {GeoResource.GEOIP: appGeoIpUrl},
        ),
      );

      expect(urls['geoip'], appGeoIpUrl);
      expect(urls['geosite'], defaultGeoXUrl[GeoResource.GEOSITE]);
    },
  );

  test('default GEO URLs are retained when neither source customizes them', () {
    final urls = resolveGeoXUrls(
      rawConfig: const {},
      patchConfig: const PatchClashConfig(),
    );

    expect(urls['geoip'], defaultGeoXUrl[GeoResource.GEOIP]);
    expect(urls['geosite'], defaultGeoXUrl[GeoResource.GEOSITE]);
  });
}

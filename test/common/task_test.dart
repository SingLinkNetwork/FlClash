import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

  test('releases a backup file when extraction fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fl_clash_restore_lock_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final backupFile = File(p.join(directory.path, 'backup.zip'));
    final restoreDir = Directory(p.join(directory.path, 'restore'));
    await restoreDir.create();
    await Directory(p.join(restoreDir.path, configJsonName)).create();
    final archive = Archive()
      ..addFile(ArchiveFile.string(configJsonName, '{}'));
    final zipBytes = ZipEncoder().encodeBytes(archive);
    await backupFile.writeAsBytes(zipBytes);

    await expectLater(
      restoreBackupArchive(backupFile.path, restoreDir.path),
      throwsA(isA<FileSystemException>()),
    );

    final result = await Process.run('lsof', ['-Fn', '-p', '$pid']);
    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains(backupFile.path)));
  });

  test('rejects a backup archive before an unsafe entry can escape', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fl_clash_zip_slip_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final backupFile = File(p.join(directory.path, 'backup.zip'));
    final restoreDir = Directory(p.join(directory.path, 'restore'));
    final archive = Archive()
      ..addFile(ArchiveFile.string('safe.txt', 'safe backup content'))
      ..addFile(ArchiveFile.string('../escaped.txt', 'escaped backup content'));
    final zipBytes = ZipEncoder().encodeBytes(archive);
    await backupFile.writeAsBytes(zipBytes);

    Object? restoreError;
    try {
      await restoreBackupArchive(backupFile.path, restoreDir.path);
    } catch (error) {
      restoreError = error;
    }

    expect(
      [
        File(p.join(restoreDir.path, 'safe.txt')).existsSync(),
        File(p.join(directory.path, 'escaped.txt')).existsSync(),
      ],
      [false, false],
    );
    expect(restoreError, isA<FileSystemException>());
  });

  test(
    'restores a nested backup entry beneath the restore directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fl_clash_restore_nested_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backupFile = File(p.join(directory.path, 'backup.zip'));
      final restoreDir = Directory(p.join(directory.path, 'restore'));
      final archive = Archive()
        ..addFile(
          ArchiveFile.string('profiles/nested.yaml', 'profile: nested\n'),
        );
      final zipBytes = ZipEncoder().encodeBytes(archive);
      await backupFile.writeAsBytes(zipBytes);

      await restoreBackupArchive(backupFile.path, restoreDir.path);

      expect(
        await File(
          p.join(restoreDir.path, 'profiles', 'nested.yaml'),
        ).readAsString(),
        'profile: nested\n',
      );
    },
  );

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

  test(
    'proxy providers with the same URL receive separate cache files',
    () async {
      const url = 'https://subscription.example/providers';
      final rawConfig = <String, dynamic>{
        'proxy-providers': {
          'provider-one': {
            'type': 'http',
            'url': url,
            'header': {
              'Id': ['file-one'],
            },
          },
          'provider-two': {
            'type': 'http',
            'url': url,
            'header': {
              'Id': ['file-two'],
            },
          },
        },
      };
      final profile = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/tmp/flclash-provider-cache-test',
          profileId: 15,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );

      expect(
        profile.a,
        contains(
          'providers/15/proxies/${'provider-one'.toMd5()}-${url.toMd5()}',
        ),
      );
      expect(
        profile.a,
        contains(
          'providers/15/proxies/${'provider-two'.toMd5()}-${url.toMd5()}',
        ),
      );
    },
  );

  test(
    'custom proxy groups discard nodes removed by a subscription refresh',
    () async {
      final profile = await makeRealProfileTask(
        const MakeRealProfileState(
          profilesPath: '/tmp/flclash-custom-groups-test',
          profileId: 16,
          rawConfig: {
            'proxies': [
              {'name': 'current-node', 'type': 'ss'},
            ],
          },
          realPatchConfig: PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: [
            ProxyGroup(
              id: 1,
              name: 'nested-group',
              type: GroupType.Selector,
              proxies: ['current-node'],
            ),
            ProxyGroup(
              id: 2,
              name: 'main-group',
              type: GroupType.Selector,
              proxies: ['current-node', 'renamed-old-node', 'nested-group'],
            ),
            ProxyGroup(
              id: 3,
              name: 'all-stale-group',
              type: GroupType.Selector,
              proxies: ['renamed-old-node'],
            ),
          ],
          rules: [],
          addedRules: [],
          defaultUA: 'FlClash-Test',
        ),
      );

      expect(profile.a, contains('current-node'));
      expect(profile.a, contains('nested-group'));
      expect(profile.a, isNot(contains('renamed-old-node')));
      expect(
        profile.a,
        contains(
          'name: "all-stale-group"\n    type: "select"\n    proxies:\n      - "DIRECT"',
        ),
      );
    },
  );

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

  test('DNS override preserves direct nameservers', () async {
    final profile = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/tmp/flclash-direct-nameserver-test',
        profileId: 12,
        rawConfig: {
          'dns': {
            'enable': true,
            'direct-nameserver': ['223.5.5.5', '119.29.29.29'],
          },
        },
        realPatchConfig: PatchClashConfig(
          dns: Dns(directNameserver: ['223.5.5.5', '119.29.29.29']),
        ),
        overrideDns: true,
        appendSystemDns: false,
        proxyGroups: [],
        rules: [],
        addedRules: [],
        defaultUA: 'FlClash-Test',
      ),
    );

    expect(profile.a, contains('direct-nameserver:'));
    expect(profile.a, contains('- "223.5.5.5"'));
    expect(profile.a, contains('- "119.29.29.29"'));
  });

  test('DNS override does not add an unset direct nameserver', () async {
    final profile = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/tmp/flclash-direct-nameserver-test',
        profileId: 13,
        rawConfig: {
          'dns': {'enable': true},
        },
        realPatchConfig: PatchClashConfig(),
        overrideDns: true,
        appendSystemDns: false,
        proxyGroups: [],
        rules: [],
        addedRules: [],
        defaultUA: 'FlClash-Test',
      ),
    );

    expect(profile.a, isNot(contains('direct-nameserver:')));
  });
}

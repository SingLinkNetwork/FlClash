import 'dart:async';

import 'package:fl_clash/common/startup.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('Startup sequencing', () {
    test(
      'waits for the core listener before publishing running state',
      () async {
        final listenerCompleter = Completer<bool>();
        final events = <String>[];

        final startFuture = startListenerBeforePublishingStatus(
          startListener: () {
            events.add('listener-called');
            return listenerCompleter.future;
          },
          updateRunTime: () => events.add('run-time'),
          updateTraffic: () async => events.add('traffic'),
        );

        expect(events, ['listener-called']);

        listenerCompleter.complete(true);
        expect(await startFuture, true);
        expect(events, ['listener-called', 'run-time', 'traffic']);
      },
    );

    test('does not publish running state when the listener fails', () async {
      final events = <String>[];

      final started = await startListenerBeforePublishingStatus(
        startListener: () async {
          events.add('listener-called');
          return false;
        },
        updateRunTime: () => events.add('run-time'),
        updateTraffic: () async => events.add('traffic'),
      );

      expect(started, false);
      expect(events, ['listener-called']);
    });
  });

  group('ProfilesAction', () {
    test('keeps edited profile data when remote update fails', () async {
      final original = Profile.normal(label: 'old label', url: 'bad-url');
      final edited = original.copyWith(
        label: 'new label',
        url: 'still-bad-url',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([original])),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profilesProvider).getProfile(original.id),
        original,
      );

      await expectLater(
        container.read(profilesActionProvider.notifier).updateProfile(edited),
        throwsA(anything),
      );

      final profile = container.read(profilesProvider).getProfile(original.id);
      expect(profile?.label, edited.label);
      expect(profile?.url, edited.url);
    });

    test(
      'restores a failed proxy selection without clobbering a newer choice',
      () {
        final profile = Profile.normal(
          label: 'test',
        ).copyWith(selectedMap: {'Proxy': 'node-a'});
        final container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            profilesProvider.overrideWith(() => _TestProfiles([profile])),
          ],
        );
        addTearDown(container.dispose);
        final action = container.read(profilesActionProvider.notifier);

        action.updateCurrentSelectedMap('Proxy', 'node-b');
        action.restoreCurrentSelectedMap(
          groupName: 'Proxy',
          expectedProxyName: 'node-b',
          previousProxyName: 'node-a',
          profileId: profile.id,
        );
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          'node-a',
        );

        action.updateCurrentSelectedMap('Proxy', 'node-c');
        action.restoreCurrentSelectedMap(
          groupName: 'Proxy',
          expectedProxyName: 'node-b',
          previousProxyName: 'node-a',
          profileId: profile.id,
        );
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          'node-c',
        );
      },
    );
  });

  group('SetupAction mode switching', () {
    test('restores the selected proxy group after leaving global mode', () {
      final profile = Profile.normal(
        label: 'test',
      ).copyWith(currentGroupName: 'Proxy', selectedMap: {'Proxy': 'node-b'});
      final groups = [
        const Group(
          name: 'GLOBAL',
          type: GroupType.Selector,
          hidden: false,
          all: [Proxy(name: 'node-a', type: 'ss')],
        ),
        const Group(
          name: 'Proxy',
          type: GroupType.Selector,
          hidden: false,
          all: [
            Proxy(name: 'node-a', type: 'ss'),
            Proxy(name: 'node-b', type: 'ss'),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          profilesProvider.overrideWith(() => _TestProfiles([profile])),
          groupsProvider.overrideWithBuild((_, _) => groups),
          patchClashConfigProvider.overrideWithBuild(
            (_, _) => const PatchClashConfig(mode: Mode.rule),
          ),
        ],
      );
      addTearDown(container.dispose);

      final action = container.read(setupActionProvider.notifier);
      action.changeMode(Mode.global);
      expect(
        container.read(currentProfileProvider)?.currentGroupName,
        'GLOBAL',
      );

      action.changeMode(Mode.rule);

      expect(container.read(currentProfileProvider)?.currentGroupName, 'Proxy');
      expect(container.read(currentProfileProvider)?.selectedMap, {
        'Proxy': 'node-b',
      });
    });
  });

  group('GeoResourceAction', () {
    test('GeoResource has correct updatingKey', () {
      expect(GeoResource.MMDB.updatingKey, 'geo_resource_MMDB');
      expect(GeoResource.ASN.updatingKey, 'geo_resource_ASN');
      expect(GeoResource.GEOIP.updatingKey, 'geo_resource_GEOIP');
      expect(GeoResource.GEOSITE.updatingKey, 'geo_resource_GEOSITE');
    });

    test('IsUpdating provider works with geo resource key', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = GeoResource.MMDB.updatingKey;
      expect(container.read(isUpdatingProvider(key)), false);

      container.read(isUpdatingProvider(key).notifier).value = true;
      expect(container.read(isUpdatingProvider(key)), true);

      container.read(isUpdatingProvider(key).notifier).value = false;
      expect(container.read(isUpdatingProvider(key)), false);
    });
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }
}

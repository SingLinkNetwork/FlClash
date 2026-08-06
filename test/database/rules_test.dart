import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  late Database database;

  setUp(() {
    database = Database(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'queryAddedRules keeps profile rules before global rules in UI order',
    () async {
      const profileId = 7;
      await database.profilesDao.putAll([
        const Profile(
          id: profileId,
          autoUpdateDuration: defaultUpdateDuration,
        ).toCompanion(),
      ]);

      await database.rulesDao.putGlobalRule(
        const Rule(
          id: 101,
          content: 'global-1.example',
          ruleTarget: 'DIRECT',
          order: 'a0V',
        ),
      );
      await database.rulesDao.putGlobalRule(
        const Rule(
          id: 102,
          content: 'global-2.example',
          ruleTarget: 'MATCH',
          order: 'a0W',
        ),
      );
      await database.rulesDao.putProfileAddedRule(
        profileId,
        const Rule(
          id: 201,
          content: 'profile-1.example',
          ruleTarget: 'DIRECT',
          order: 'a0V',
        ),
      );
      await database.rulesDao.putProfileAddedRule(
        profileId,
        const Rule(
          id: 202,
          content: 'profile-2.example',
          ruleTarget: 'MATCH',
          order: 'a0W',
        ),
      );

      final rules = await database.rulesDao.queryAddedRules(profileId).get();

      expect(rules.map((rule) => rule.content).toList(), [
        'profile-1.example',
        'profile-2.example',
        'global-1.example',
        'global-2.example',
      ]);
    },
  );

  test('keeps multiple global and profile rules as separate entries', () async {
    const profileId = 8;
    await database.profilesDao.putAll([
      const Profile(
        id: profileId,
        autoUpdateDuration: defaultUpdateDuration,
      ).toCompanion(),
    ]);

    await database.rulesDao.putGlobalRule(
      const Rule(
        id: 301,
        content: 'global.example',
        ruleTarget: 'DIRECT',
        order: 'a0V',
      ),
    );
    await database.rulesDao.putGlobalRule(
      const Rule(
        id: 302,
        content: 'global-second.example',
        ruleTarget: 'MATCH',
        order: 'a0W',
      ),
    );
    await database.rulesDao.putProfileAddedRule(
      profileId,
      const Rule(
        id: 401,
        content: 'profile.example',
        ruleTarget: 'DIRECT',
        order: 'a0V',
      ),
    );
    await database.rulesDao.putProfileAddedRule(
      profileId,
      const Rule(
        id: 402,
        content: 'profile-second.example',
        ruleTarget: 'MATCH',
        order: 'a0W',
      ),
    );

    expect(
      (await database.rulesDao.queryGlobalAddedRules().get())
          .map((rule) => rule.id)
          .toList(),
      [301, 302],
    );
    expect(
      (await database.rulesDao.queryProfileAddedRules(profileId).get())
          .map((rule) => rule.id)
          .toList(),
      [401, 402],
    );
  });

  test(
    'puts added rules before the built-in rules in the generated profile',
    () async {
      final profile = await makeRealProfileTask(
        const MakeRealProfileState(
          profilesPath: '/tmp/flclash-rules-test',
          profileId: 9,
          rawConfig: {
            'rules': ['DOMAIN,builtin.example,DIRECT'],
          },
          realPatchConfig: PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: [],
          rules: [],
          addedRules: [
            Rule(id: 501, content: 'override.example', ruleTarget: 'DIRECT'),
          ],
          defaultUA: 'FlClash-Test',
        ),
      );

      expect(
        profile.a.indexOf('override.example'),
        lessThan(profile.a.indexOf('builtin.example')),
      );
    },
  );
}

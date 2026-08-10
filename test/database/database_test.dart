import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  test(
    'repairs legacy profiles with a missing label before reading them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-db-test-',
      );
      final file = File('${directory.path}/data.sqlite');
      final legacyDatabase = sqlite.sqlite3.open(file.path);
      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      legacyDatabase.execute('''
      CREATE TABLE profiles (
        id INTEGER NOT NULL PRIMARY KEY,
        label TEXT,
        current_group_name TEXT,
        url TEXT NOT NULL,
        last_update_date INTEGER,
        overwrite_type TEXT NOT NULL,
        script_id INTEGER,
        auto_update_duration_millis INTEGER NOT NULL,
        subscription_info TEXT,
        auto_update INTEGER NOT NULL,
        selected_map TEXT NOT NULL,
        unfold_set TEXT NOT NULL,
        "order" INTEGER
      );
    ''');
      legacyDatabase.execute('''
      INSERT INTO profiles (
        id, label, url, overwrite_type, auto_update_duration_millis,
        auto_update, selected_map, unfold_set
      ) VALUES (1, NULL, '', 'standard', 0, 0, '{}', '[]');
    ''');
      legacyDatabase.execute('PRAGMA user_version = 2;');
      legacyDatabase.dispose();

      final database = Database(NativeDatabase(file));
      addTearDown(database.close);

      final profiles = await database.profilesDao.query().get();

      expect(profiles.single.label, isEmpty);
    },
  );
}

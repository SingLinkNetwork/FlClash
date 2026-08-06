import 'package:fl_clash/common/sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('macOS bundled SQLite path', () {
    test('resolves CSQLite next to the macOS executable', () {
      expect(
        macOSSqliteLibraryPath(
          executablePath:
              '/Applications/FlClash.app/Contents/MacOS/FlClash',
        ),
        '/Applications/FlClash.app/Contents/Frameworks/CSQLite.framework/CSQLite',
      );
    });

    test('does not resolve a macOS path for other platforms', () {
      expect(
        macOSSqliteLibraryPath(
          executablePath: '/tmp/flclash',
          isMacOS: false,
        ),
        isNull,
      );
    });
  });
}

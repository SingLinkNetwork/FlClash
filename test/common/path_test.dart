import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('resolveExistingDirectoryPath', () {
    test('returns the path when the directory exists', () async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-picker-test-',
      );
      try {
        expect(
          await resolveExistingDirectoryPath(Future.value(directory)),
          directory.path,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('returns null when the platform has no downloads directory', () async {
      expect(
        await resolveExistingDirectoryPath(Future<Directory?>.value()),
        isNull,
      );
    });

    test('returns null when the directory no longer exists', () async {
      expect(
        await resolveExistingDirectoryPath(
          Future.value(Directory('/path/that/does/not/exist')),
        ),
        isNull,
      );
    });

    test('returns null when the platform lookup fails', () async {
      expect(
        await resolveExistingDirectoryPath(
          Future<Directory?>.error(StateError('downloads unavailable')),
        ),
        isNull,
      );
    });

    test('returns null when the platform lookup does not finish', () async {
      final directory = Completer<Directory?>();
      expect(
        await resolveExistingDirectoryPath(
          directory.future,
          timeout: const Duration(milliseconds: 1),
        ),
        isNull,
      );
    });
  });

  group('portable Windows data path', () {
    test('uses executable directory when Windows directory is writable', () {
      expect(
        resolvePortableDataRoot(
          isWindows: true,
          executableDirectory: p.join('USB', 'FlClash'),
          appDirectoryWritable: true,
        ),
        p.join('USB', 'FlClash', 'data'),
      );
    });

    test('falls back when the executable directory is not writable', () {
      expect(
        resolvePortableDataRoot(
          isWindows: true,
          executableDirectory: p.join('Program Files', 'FlClash'),
          appDirectoryWritable: false,
        ),
        isNull,
      );
    });

    test('does not change non-Windows data locations', () {
      expect(
        resolvePortableDataRoot(
          isWindows: false,
          executableDirectory: p.join('Applications', 'FlClash.app'),
          appDirectoryWritable: true,
        ),
        isNull,
      );
    });
  });
}

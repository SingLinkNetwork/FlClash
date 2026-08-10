import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/picker.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformFileExt.readBytes', () {
    test('loads bytes from the picked file path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'fl_clash_picker_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final file = File('${directory.path}/profile.yaml');
      await file.writeAsString('mixed-port: 7890');

      final platformFile = PlatformFile(
        name: 'profile.yaml',
        path: file.path,
        size: await file.length(),
      );

      final bytes = await platformFile.readBytes();

      expect(String.fromCharCodes(bytes), 'mixed-port: 7890');
    });

    test(
      'copies a bytes-only picked file to the restore destination',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'fl_clash_picker_restore_test_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final destination = File('${directory.path}/backup.zip');
        final platformFile = PlatformFile(
          name: 'backup.zip',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        await copyPickedFileToPath(platformFile, destination.path);

        expect(await destination.readAsBytes(), [1, 2, 3]);
      },
    );

    test(
      'copies a path-backed picked file to the restore destination',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'fl_clash_picker_restore_path_test_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final source = File('${directory.path}/source.zip');
        final destination = File('${directory.path}/backup.zip');
        await source.writeAsBytes([4, 5, 6]);
        final platformFile = PlatformFile(
          name: 'source.zip',
          path: source.path,
          size: 3,
        );

        await copyPickedFileToPath(platformFile, destination.path);

        expect(await destination.readAsBytes(), [4, 5, 6]);
      },
    );
  });
}

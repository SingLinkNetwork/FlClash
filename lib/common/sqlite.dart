import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

String? macOSSqliteLibraryPath({
  required String executablePath,
  bool isMacOS = true,
}) {
  if (!isMacOS) return null;

  final executableDirectory = File(executablePath).parent.path;
  return p.normalize(
    p.join(
      executableDirectory,
      '..',
      'Frameworks',
      'CSQLite.framework',
      'CSQLite',
    ),
  );
}

void configureMacOSSqlite() {
  if (!Platform.isMacOS) return;

  final libraryPath = macOSSqliteLibraryPath(
    executablePath: Platform.resolvedExecutable,
  );
  if (libraryPath == null || !File(libraryPath).existsSync()) return;

  open.overrideFor(
    OperatingSystem.macOS,
    () => DynamicLibrary.open(libraryPath),
  );
}

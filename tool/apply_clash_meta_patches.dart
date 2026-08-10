import 'dart:io';

// The build tool is a separate local Dart package; this command intentionally
// delegates to its shared patch implementation rather than duplicating it.
// ignore: avoid_relative_lib_imports
import '../plugins/setup/buildkit/build_tool/lib/src/clash_meta_patches.dart';

Future<void> main() async {
  try {
    final rootDir = File.fromUri(Platform.script).parent.parent.path;
    await applyClashMetaPatches(rootDir);
  } catch (error, stackTrace) {
    stderr.writeln('Failed to apply Clash.Meta patches: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

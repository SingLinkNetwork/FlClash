import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP overrides never bypass TLS certificate validation', () {
    final source = File('lib/common/http.dart').readAsStringSync();

    expect(source, isNot(contains('badCertificateCallback')));
  });
}

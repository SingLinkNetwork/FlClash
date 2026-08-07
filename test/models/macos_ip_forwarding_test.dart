import 'package:fl_clash/models/config.dart';
import 'package:test/test.dart';

void main() {
  test('macOS IP forwarding is disabled by default', () {
    expect(const AppSettingProps().macOSIpForwarding, isFalse);
  });

  test('macOS IP forwarding survives settings serialization', () {
    const settings = AppSettingProps(macOSIpForwarding: true);
    final restored = AppSettingProps.fromJson(settings.toJson());

    expect(restored.macOSIpForwarding, isTrue);
  });
}

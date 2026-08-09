import 'package:fl_clash/common/navigation.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:test/test.dart';

void main() {
  test('keeps proxy navigation when profiles exist before groups load', () {
    final items = navigation.getItems(hasProfiles: true);
    final proxyItem = items.firstWhere(
      (item) => item.label == PageLabel.proxies,
    );

    expect(proxyItem.modes, containsAll([
      NavigationItemMode.mobile,
      NavigationItemMode.desktop,
    ]));
  });

  test('hides proxy navigation when no profile exists', () {
    final items = navigation.getItems(hasProfiles: false);
    final proxyItem = items.firstWhere(
      (item) => item.label == PageLabel.proxies,
    );

    expect(proxyItem.modes, isEmpty);
  });
}

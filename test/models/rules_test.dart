import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('RuleExt', () {
    test('allows MATCH rules without content', () {
      const rule = Rule(ruleAction: RuleAction.MATCH, ruleTarget: 'DIRECT');

      expect(rule.hasValidContent, isTrue);
      expect(rule.rawValue, 'MATCH,DIRECT');
    });

    test('still requires content for regular rules', () {
      const rule = Rule(ruleAction: RuleAction.DOMAIN, ruleTarget: 'DIRECT');

      expect(rule.hasValidContent, isFalse);
    });

    test('round-trips MATCH rules without an extra content column', () {
      final rule = Rule.parse('MATCH,DIRECT');

      expect(rule.realContent, isNull);
      expect(rule.realTarget, 'DIRECT');
      expect(rule.rawValue, 'MATCH,DIRECT');
    });
  });
}

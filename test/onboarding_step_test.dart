import 'package:flutter_test/flutter_test.dart';
import 'package:ramadan_reflections/components/onboarding/onboarding_step.dart';

void main() {
  group('OnboardingStep', () {
    test('all contains known steps', () {
      expect(OnboardingStep.all.length, 20);
      final names = OnboardingStep.all.map((s) => s.name);
      expect(names, contains('welcome'));
      expect(names, contains('music_selection'));
      expect(names, contains('name'));
      expect(names, contains('google_signin'));
      expect(names, contains('email'));
      expect(names, contains('store_paywall'));
    });

    test('steps have sequential indices', () {
      for (int i = 0; i < OnboardingStep.all.length; i++) {
        expect(OnboardingStep.all[i].index, i);
      }
    });

    test('fromIndex returns correct step', () {
      final step = OnboardingStep.fromIndex(0);
      expect(step.name, 'welcome');
    });

    test('welcome page has no onBack', () {
      final step = OnboardingStep.fromIndex(0);
      expect(step.name, 'welcome');
    });

    test('store paywall is last (after email)', () {
      final last = OnboardingStep.all.last;
      expect(last.name, 'store_paywall');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/services/entitlement_service.dart';

const String _uid = 'u1';
const String _install = 'testinstall';

/// Trial start key for the mocked install. Firebase is not initialized in
/// unit tests, so LocalTrialService resolves no uid and uses the
/// install-only key form.
String get _trialKey => 'local_trial_start_install_$_install';

Map<String, Object> _basePrefs() => {
      'meowmin_install_id': _install,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(_basePrefs());
    EntitlementService.fetchOverride = null;
    EntitlementService.resetMemo();
  });

  tearDown(() {
    EntitlementService.fetchOverride = null;
    EntitlementService.resetMemo();
  });

  group('verdict parsing', () {
    test('parses active + reason from the server payload', () {
      final v = EntitlementVerdict.fromJson({
        'active': true,
        'reason': 'trial',
        'daysRemaining': 2,
      });
      expect(v.active, isTrue);
      expect(v.reason, 'trial');
      expect(v.isDenied, isFalse);
    });

    test('flags the positive denial reasons', () {
      for (final reason in [
        'trial_expired',
        'device_claimed',
        'no_trial_stale',
      ]) {
        final v = EntitlementVerdict.fromJson({'active': false, 'reason': reason});
        expect(v.isDenied, isTrue, reason: reason);
      }
      // "unknown" means we could not tell, not that access is denied.
      final unknown =
          EntitlementVerdict.fromJson({'active': false, 'reason': 'unknown'});
      expect(unknown.isDenied, isFalse);
    });
  });

  group('shouldLock', () {
    test('signed out never locks (onboarding owns the flow)', () async {
      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: '',
      );
      expect(locked, isFalse);
    });

    test('an active store entitlement always unlocks', () async {
      EntitlementService.fetchOverride = () async => null;
      final locked = await EntitlementService.shouldLock(
        subscribed: true,
        uidOverride: _uid,
      );
      expect(locked, isFalse);
    });

    test('a server denial locks even with an active local trial', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        ..._basePrefs(),
        _trialKey: now,
        'trial_max_seen_now_ms': now,
      });
      EntitlementService.fetchOverride = () async =>
          const EntitlementVerdict(active: false, reason: 'trial_expired');

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isTrue);

      // ...and the denial is cached, so it survives the next check.
      final cached = await EntitlementService.cached();
      expect(cached?.active, isFalse);
    });

    test('a server allow unlocks', () async {
      EntitlementService.fetchOverride = () async =>
          const EntitlementVerdict(active: true, reason: 'trial');

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isFalse);
      expect((await EntitlementService.cached())?.active, isTrue);
    });

    test('a cached denial stays sticky while offline', () async {
      EntitlementService.fetchOverride = () async => null;
      await EntitlementService.cache(
        const EntitlementVerdict(active: false, reason: 'trial_expired'),
      );

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isTrue);
    });

    test('a fresh cached allow keeps working offline', () async {
      EntitlementService.fetchOverride = () async => null;
      await EntitlementService.cache(
        const EntitlementVerdict(active: true, reason: 'trial'),
      );

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isFalse);
    });

    test('a stale cached allow falls back to the local clock (expired)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        ..._basePrefs(),
        'entitlement_cache_json':
            '{"active":true,"reason":"trial"}',
        'entitlement_cache_at_ms':
            now - const Duration(hours: 13).inMilliseconds,
        // Trial long over: 10 days ago, high-water mark at "now".
        _trialKey: now - const Duration(days: 10).inMilliseconds,
        'trial_max_seen_now_ms': now,
      });
      EntitlementService.fetchOverride = () async => null;

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isTrue);
    });

    test('offline with no verdict keeps a live local trial running', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        ..._basePrefs(),
        _trialKey: now,
        'trial_max_seen_now_ms': now,
      });
      EntitlementService.fetchOverride = () async => null;

      final locked = await EntitlementService.shouldLock(
        subscribed: false,
        uidOverride: _uid,
      );
      expect(locked, isFalse);
    });

    test('clear() drops a cached denial after a purchase', () async {
      EntitlementService.fetchOverride = () async => null;
      await EntitlementService.cache(
        const EntitlementVerdict(active: false, reason: 'trial_expired'),
      );
      expect(await EntitlementService.cached(), isNotNull);

      await EntitlementService.clear();
      expect(await EntitlementService.cached(), isNull);
    });
  });
}

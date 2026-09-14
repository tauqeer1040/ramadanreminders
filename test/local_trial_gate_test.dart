import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/services/local_trial_service.dart';

/// Unit tests for LocalTrialService gate math.
///
/// The device clock cannot be mocked directly, so clock-rollback is
/// simulated by seeding `trial_max_seen_now_ms` (the high-water mark) to a
/// FUTURE value: the effective "now" then runs ahead of the real clock,
/// exactly as it would if the user had rolled the clock back after the
/// trial clock had legitimately advanced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dayMs = 24 * 60 * 60 * 1000;
  const trialMs = 3 * dayMs;
  const graceMs = 3 * dayMs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('trial clock (rollback-proof elapsed math)', () {
    test('fresh trial with no start -> not active, not expired', () async {
      expect(await LocalTrialService.isActive(), false);
      expect(await LocalTrialService.isExpired(), false);
      expect(await LocalTrialService.hasStarted(), false);
    });

    test('trial started now -> active, remaining ~3 days', () async {
      await LocalTrialService.startTrial();
      expect(await LocalTrialService.hasStarted(), true);
      expect(await LocalTrialService.isActive(), true);
      expect(await LocalTrialService.isExpired(), false);
      final remaining = await LocalTrialService.remaining();
      expect(remaining.inHours, inInclusiveRange(71, 72));
    });

    test('clock rolled back cannot shrink elapsed time', () async {
      await LocalTrialService.startTrial();
      final prefs = await SharedPreferences.getInstance();
      // Simulate: real clock legitimately ran 4 days ahead (trial over),
      // then the user rolled the device clock back to trial day 0.
      await prefs.setInt('trial_max_seen_now_ms',
          DateTime.now().millisecondsSinceEpoch + 4 * dayMs);
      // Effective now is +4d -> trial elapsed -> expired even though the
      // device clock says day 0.
      expect(await LocalTrialService.isActive(), false);
      expect(await LocalTrialService.isExpired(), true);
      expect(await LocalTrialService.remaining(), Duration.zero);
    });

    test('high-water mark never decreases across calls', () async {
      await LocalTrialService.startTrial();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('trial_max_seen_now_ms',
          DateTime.now().millisecondsSinceEpoch + 10 * dayMs);
      // Multiple reads keep the advanced clock (never fall back to the
      // real, rolled-back clock).
      expect(await LocalTrialService.isExpired(), true);
      expect(await LocalTrialService.isExpired(), true);
    });

    test('server denial overrides an active local clock', () async {
      await LocalTrialService.startTrial();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('server_trial_denied', true);
      expect(await LocalTrialService.isActive(), false);
      expect(await LocalTrialService.hasStarted(), true);
    });

    test('server-denied device routes to hard gate via isPastGrace',
        () async {
      await LocalTrialService.startTrial();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('server_trial_denied', true);
      // hasStarted() is true for denied devices, soft window is closed ->
      // past grace -> every gate (splash, resume, Write) hard-locks.
      expect(await LocalTrialService.isPastGrace(), true);
    });
  });

  group('post-expiry grace window', () {
    test('never-subscribed -> no grace', () async {
      expect(await LocalTrialService.isInPostExpiryGrace(), false);
    });

    test('grace active counts as soft window', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('had_max_subscription', true);
      await prefs.setInt('post_expiry_grace_start_ms',
          DateTime.now().millisecondsSinceEpoch);
      expect(await LocalTrialService.isInPostExpiryGrace(), true);
      expect(await LocalTrialService.isSoftWindow(), true);
      expect(await LocalTrialService.isPastGrace(), false);
    });

    test('grace period survives a rolled-back clock', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('had_max_subscription', true);
      await prefs.setInt('post_expiry_grace_start_ms',
          DateTime.now().millisecondsSinceEpoch);
      // Clock jumped 4 days ahead (grace over), then rolled back to 0.
      await prefs.setInt('trial_max_seen_now_ms',
          DateTime.now().millisecondsSinceEpoch + 4 * dayMs);
      expect(await LocalTrialService.isInPostExpiryGrace(), false);
      expect(await LocalTrialService.isSoftWindow(), false);
    });

    test('expired trial + grace over -> past grace', () async {
      await LocalTrialService.startTrial();
      final prefs = await SharedPreferences.getInstance();
      // Trial started 10 days ago by the high-water clock.
      await prefs.setInt('trial_max_seen_now_ms',
          DateTime.now().millisecondsSinceEpoch + 10 * dayMs);
      expect(await LocalTrialService.isPastGrace(), true);
    });

    test('no trial started -> never past grace', () async {
      expect(await LocalTrialService.isPastGrace(), false);
    });
  });

  group('syncSubscriptionState', () {
    test('subscribed arms ever-subscribed and clears grace', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('post_expiry_grace_start_ms',
          DateTime.now().millisecondsSinceEpoch - graceMs + 1000);
      await LocalTrialService.syncSubscriptionState(true);
      expect(prefs.getBool('had_max_subscription'), true);
      expect(prefs.getInt('post_expiry_grace_start_ms'), null);
    });

    test('first inactive flip after subscribing starts grace', () async {
      await LocalTrialService.syncSubscriptionState(true);
      await LocalTrialService.syncSubscriptionState(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('post_expiry_grace_start_ms'), isNotNull);
      expect(await LocalTrialService.isInPostExpiryGrace(), true);
    });

    test('never-subscribed users never get grace', () async {
      await LocalTrialService.syncSubscriptionState(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('post_expiry_grace_start_ms'), null);
      expect(await LocalTrialService.isInPostExpiryGrace(), false);
    });
  });
}

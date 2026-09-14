import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/components/widgets/streak_graph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keys mirror InviteService's private consts.
  const linkedUidKey = 'friend_linked_uid';
  const friendNameKey = 'friend_display_name';
  const friendCatKey = 'friend_cat_name';

  // The graph renders a DeferredLottie, whose deferred library load leaves
  // a real (non-fake-async) timer pending at teardown. runAsync lets real
  // timers flush so the binding's no-pending-timers invariant holds.
  Future<void> pumpGraph(WidgetTester tester, {required bool shieldActive}) {
    return tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StreakGraph(streak: 5, size: 200, shieldActive: shieldActive),
        ),
      ));
      // Let the friend-label future resolve (isFriendLinked -> getFriendLabel).
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
  }

  testWidgets('shows shield-only line when no friend linked',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpGraph(tester, shieldActive: true);
    await tester.pump();
    expect(find.text('streak shield active'), findsOneWidget);
  });

  testWidgets('shows friend-only line when linked but no shield',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      linkedUidKey: 'friend-uid',
      friendNameKey: 'John',
    });
    await pumpGraph(tester, shieldActive: false);
    await tester.pump();
    expect(find.text('streak protected by John'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
  });

  testWidgets('shows combined line with shield and friend', (tester) async {
    SharedPreferences.setMockInitialValues({
      linkedUidKey: 'friend-uid',
      friendNameKey: 'John',
      friendCatKey: 'Whiskers',
    });
    await pumpGraph(tester, shieldActive: true);
    await tester.pump();
    expect(find.text('streak protected with shield & Whiskers (John)'),
        findsOneWidget);
  });

  testWidgets('no protection line when neither shield nor friend',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpGraph(tester, shieldActive: false);
    await tester.pump();
    expect(find.text('streak shield active'), findsNothing);
    expect(find.byIcon(Icons.shield_rounded), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/revenuecat_service.dart';
import '../services/revenuecat_provider.dart';
import '../theme/app_theme.dart';
import '../core/app_background.dart';
import '../components/widgets/duo_button.dart';

class ManageAccountScreen extends ConsumerWidget {
  final User user;

  const ManageAccountScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueCat = ref.watch(revenueCatProvider);
    final isPro = revenueCat.isPro;
    final expiresDate = (() {
      final ent = revenueCat.customerInfo?.entitlements.active[RevenueCatService.entitlementId];
      if (ent?.expirationDate == null) return null;
      return DateTime.tryParse(ent!.expirationDate!);
    })();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Manage Account',
          style: TextStyle(
            color: AppTheme.starWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.starWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonPurple, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonPurple.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: user.photoURL != null
                        ? ClipOval(child: Image.network(user.photoURL!, fit: BoxFit.cover))
                        : Icon(Icons.person, size: 50, color: AppTheme.ghostSilver),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    user.email ?? '',
                    style: const TextStyle(
                      color: AppTheme.ghostSilver,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // ── Subscription card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.neonPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(isPro ? Icons.star_rounded : Icons.star_border_rounded, color: AppTheme.starGold, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPro ? 'Meowmin Max — Active' : 'Free Plan',
                              style: const TextStyle(color: AppTheme.starWhite, fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            if (isPro && expiresDate != null)
                              Text(
                                'Renews ${expiresDate.day}/${expiresDate.month}/${expiresDate.year}',
                                style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.8), fontSize: 11),
                              )
                            else
                              Text(
                                isPro ? 'Tap Manage to see details' : '3-day trial · 280 chars · upgrade for unlimited',
                                style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.8), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      if (isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.starGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('MAX', style: TextStyle(color: AppTheme.starGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DuoButton(
                    onPressed: () async {
                      await RevenueCatService.instance.presentCustomerCenter();
                      if (context.mounted) ref.read(revenueCatProvider.notifier).refresh();
                    },
                    backgroundColor: AppTheme.neonPurple,
                    depthColor: const Color(0xFF6A00FF),
                    radius: 12,
                    height: 48,
                    child: Text(
                      isPro ? 'Manage Subscription' : 'View Plans',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Pause highlight ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.starGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.starGold.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppTheme.starGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.pause_circle_rounded, color: AppTheme.starGold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Need a break? Pause instead of canceling', style: TextStyle(color: AppTheme.starWhite, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Pause keeps your shields and streak intact. You can pause for up to 3 months and resume anytime — your 114 Surahs progress stays safe.',
                          style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.85), fontSize: 11, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await RevenueCatService.instance.presentCustomerCenter();
                            if (context.mounted) ref.read(revenueCatProvider.notifier).refresh();
                          },
                          child: const Text('Pause in Manage Subscription →', style: TextStyle(color: AppTheme.starGold, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: AppTheme.starGold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'ACCOUNT ACTIONS',
              style: TextStyle(
                color: AppTheme.ghostSilver,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              onPressed: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              backgroundColor: const Color(0xFF1E1E2E),
              depthColor: const Color(0xFF0D0D1A),
              height: 60,
              radius: 12,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text(
                      'Delete all data?',
                      style: TextStyle(color: AppTheme.starWhite),
                    ),
                    content: const Text(
                      'Your data will be kept for 30 days before permanent deletion. This cannot be undone.',
                      style: TextStyle(color: AppTheme.ghostSilver),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await UserService.deleteUserAccount(user);
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: const Text(
                          'DELETE',
                          style: TextStyle(color: Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: const Color(0xFF0D0D1A),
              depthColor: Colors.black,
              height: 60,
              radius: 12,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever_rounded, color: AppTheme.ghostSilver, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Delete My Account',
                    style: TextStyle(
                      color: AppTheme.ghostSilver,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

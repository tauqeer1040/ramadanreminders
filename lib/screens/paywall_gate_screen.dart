import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:ramadan_reflections/services/revenuecat_service.dart';
import 'package:ramadan_reflections/services/revenuecat_provider.dart';
import '../theme/app_theme.dart';
import '../components/widgets/duo_button.dart';
import '../services/trial_service.dart';

/// Trial gate. IAP-first: the expired-trial hard gate presents the
/// RevenueCat paywall non-dismissable (no close button, no back). The
/// dismissable variant offers "continue trial" during the 3-day window.
/// Email plays no role here (see EmailGateScreen / onboarding step 19).
class PaywallGateScreen extends ConsumerStatefulWidget {
  final bool isDismissable;
  final VoidCallback onSubscribe;
  final VoidCallback onDismiss;

  const PaywallGateScreen({
    super.key,
    required this.isDismissable,
    required this.onSubscribe,
    required this.onDismiss,
  });

  @override
  ConsumerState<PaywallGateScreen> createState() => _PaywallGateScreenState();
}

class _PaywallGateScreenState extends ConsumerState<PaywallGateScreen> {
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _loadRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _loadRemaining());
    if (!widget.isDismissable) {
      // Non-dismissable post-trial gate: open the paywall immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRemaining() async {
    final status = await TrialService.getStatus();
    if (!mounted) return;
    setState(() {
      _remainingSeconds = (status.graceMs / 1000).ceil().clamp(0, 99999);
    });
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min}m ${sec}s';
  }

  Future<void> _subscribe() async {
    if (!mounted || _subscribing) return;
    HapticFeedback.mediumImpact();
    setState(() => _subscribing = true);
    try {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await RevenueCatService.instance.identify(uid);
        }
      } catch (_) {}
      final result = await RevenueCatService.instance.presentPaywall(
        // Hard gate: no close button — the only exits are purchase,
        // restore, or (dismissable variant) continuing the trial.
        displayCloseButton: widget.isDismissable,
      );
      if (!mounted) return;
      ref.read(revenueCatProvider.notifier).refresh();
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        widget.onSubscribe();
      } else if (result == PaywallResult.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Plans are unavailable — check your connection and try again',
              ),
            ),
          );
        }
      }
      // Cancelled on the hard gate: stay put (button below retries).
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.lightImpact();
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      ref.read(revenueCatProvider.notifier).refresh();
      if (RevenueCatService.instance.hasActiveEntitlement(info)) {
        widget.onSubscribe();
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: widget.isDismissable,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D0D1A),
                Color(0xFF1A1A2E),
                Color(0xFF0D0D1A),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonPurple.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/photos/mascot/face.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.neonPurple.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.neonPurple,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Keep Meowmin Independent',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isDismissable
                        ? 'Your 3-day trial is running. Go Max anytime to keep unlimited journaling after it ends.'
                        : 'Your 3-day trial has ended. Go Max to keep unlimited journaling, AI insights, and your streak alive.',
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 24),
                  if (!widget.isDismissable) ...[
                    SizedBox(
                      width: double.infinity,
                      child: DuoButton(
                        onPressed: _subscribing ? null : _subscribe,
                        backgroundColor: Colors.white,
                        depthColor: Colors.black,
                        borderGradientColors: kRainbowBorderColors,
                        animateBorder: true,
                        radius: 16,
                        height: 56,
                        child: _subscribing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Get Max',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: DuoButton(
                        onPressed: () => widget.onDismiss(),
                        backgroundColor: AppTheme.starGold,
                        depthColor: const Color(0xFFD4A20C),
                        radius: 16,
                        height: 56,
                        child: Text(
                          'Continue free trial — ${_formatTime(_remainingSeconds)} left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _restorePurchases,
                    child: Text(
                      'Restore Purchases',
                      style: TextStyle(
                        color: AppTheme.ghostSilver.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.isDismissable) ...[
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Column(
                        children: [
                          Text(
                            'Try for ${_formatTime(_remainingSeconds)}',
                            style: TextStyle(
                              color: AppTheme.ghostSilver.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This launch costs 1 minute of your trial',
                            style: TextStyle(
                              color: AppTheme.ghostSilver.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'One subscription unlocks everything on all your devices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.ghostSilver.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

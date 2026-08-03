import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:ramadan_reflections/services/revenuecat_service.dart';
import 'package:ramadan_reflections/services/revenuecat_provider.dart';
import '../theme/app_theme.dart';
import '../components/widgets/duo_button.dart';
import '../services/trial_service.dart';

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
  bool _presentingPaywall = false;

  @override
  void initState() {
    super.initState();
    _loadRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _loadRemaining());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRemaining() async {
    final status = await TrialService.getStatus();
    if (mounted) setState(() => _remainingSeconds = (status.graceMs / 1000).ceil().clamp(0, 99999));
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min}m ${sec}s';
  }

  Future<void> _showPaywall() async {
    if (_presentingPaywall) return;
    _presentingPaywall = true;
    HapticFeedback.mediumImpact();

    try {
      final result = await RevenueCatService.instance.presentPaywall(
        displayCloseButton: widget.isDismissable,
      );

      if (result == PaywallResult.purchased || result == PaywallResult.restored) {
        if (mounted) {
          ref.read(revenueCatProvider.notifier).refresh();
          widget.onSubscribe();
        }
      }
    } finally {
      _presentingPaywall = false;
    }
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.lightImpact();
    try {
      await RevenueCatService.instance.restorePurchases();
      if (mounted) {
        ref.read(revenueCatProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases restored successfully')),
          );
        }
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
                        'assets/photos/mascot/face.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.neonPurple.withValues(alpha: 0.2),
                          child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.neonPurple, size: 48),
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
                    'For less than the price of a coffee, support a small team that keeps your spiritual journey private, ad-free, and beautiful.',
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '\$1',
                          style: TextStyle(
                            color: Color(0xFFFF6D00),
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3-Day Trial',
                              style: TextStyle(
                                color: AppTheme.starWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Then \$79.99/yr or \$9.99/mo',
                              style: TextStyle(
                                color: AppTheme.ghostSilver,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: DuoButton(
                      onPressed: _showPaywall,
                      backgroundColor: const Color(0xFFFF6D00),
                      depthColor: const Color(0xFFE65100),
                      radius: 16,
                      height: 56,
                      child: const Text(
                        'Start Your \$1 Trial',
                        style: TextStyle(
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
                              color: AppTheme.ghostSilver.withValues(alpha: 0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This launch costs 1 minute of your trial',
                            style: TextStyle(
                              color: AppTheme.ghostSilver.withValues(alpha: 0.4),
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
                        'Your free trial has ended. Subscribe to continue using Meowmin.',
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../theme/app_theme.dart';
import '../components/widgets/duo_button.dart';
import '../services/trial_service.dart';

class PaywallGateScreen extends StatefulWidget {
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
  State<PaywallGateScreen> createState() => _PaywallGateScreenState();
}

class _PaywallGateScreenState extends State<PaywallGateScreen> {
  int _remainingSeconds = 0;
  Timer? _timer;

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
    final ms = await TrialService.getRemainingMs();
    if (mounted) setState(() => _remainingSeconds = (ms / 1000).ceil().clamp(0, 99999));
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min}m ${sec}s';
  }

  void _showPaywall() {
    HapticFeedback.mediumImpact();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Superwall.shared.identify(user.uid);
      }
    } catch (_) {}
    Superwall.shared.registerPlacement('campaign_trigger', feature: () {
      if (mounted) widget.onSubscribe();
    });
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
                  // Mascot
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
                        'assets/photos/mascot/hi.webp',
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
                  // Pricing card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.starGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.starGold.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '\$1',
                              style: TextStyle(
                                color: AppTheme.starGold,
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
                                  'Then \$59/yr or \$9/mo',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    child: DuoButton(
                      onPressed: _showPaywall,
                      backgroundColor: AppTheme.starGold,
                      depthColor: AppTheme.starGold.withValues(alpha: 0.6),
                      radius: 16,
                      height: 56,
                      child: const Text(
                        'Start Your \$1 Trial',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Dismiss / grace timer
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

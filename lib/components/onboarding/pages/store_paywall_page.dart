import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../services/analytics_service.dart';
import '../../../services/revenuecat_service.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/duo_button.dart';
import '../onboarding_data.dart';

/// Step 20 (after Email): launch the RevenueCat store paywall.
///
/// The sheet opens automatically on first show. Every outcome resolves
/// forward — purchase/restore continues into the app, dismiss/error falls
/// back to this page's inline actions (retry, restore, continue on the
/// local free trial) so the user is never trapped.
class StorePaywallPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StorePaywallPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<StorePaywallPage> createState() => _StorePaywallPageState();
}

class _StorePaywallPageState extends State<StorePaywallPage> {
  bool _presented = false;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPaywall());
  }

  Future<void> _showPaywall() async {
    if (_presented || !mounted) return;
    _presented = true;
    setState(() => _busy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        try {
          await RevenueCatService.instance.identify(uid);
        } catch (_) {}
      }
      try {
        AnalyticsService.instance.logEvent('paywall_presented', params: {'source': 'onboarding'});
      } catch (_) {}
      final result = await RevenueCatService.instance.presentPaywall();
      if (!mounted) return;
      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          try {
            AnalyticsService.instance.logEvent('paywall_purchased', params: {'source': 'onboarding'});
          } catch (_) {}
          widget.onNext();
        case PaywallResult.cancelled:
        case PaywallResult.notPresented:
          try {
            AnalyticsService.instance.logEvent('paywall_dismissed', params: {'source': 'onboarding'});
          } catch (_) {}
          widget.onNext();
        case PaywallResult.error:
          setState(() {
            _busy = false;
            _failed = true;
          });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      if (RevenueCatService.instance.hasActiveEntitlement(info)) {
        widget.onNext();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed — check your connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),
          if (_busy) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Loading plans…',
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ] else ...[
            Text(
              _failed ? 'Plans are unavailable right now' : 'Support Meowmin',
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _failed
                  ? 'Check your connection and try again — or continue on your free trial.'
                  : 'Unlock Meowmin Max and keep your spiritual home independent.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: DuoButton(
                onPressed: () {
                  _presented = false;
                  _failed = false;
                  _showPaywall();
                },
                backgroundColor: AppTheme.starGold,
                depthColor: AppTheme.starGold.withValues(alpha: 0.6),
                radius: 16,
                height: 56,
                child: const Text(
                  'See plans',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: Text(
              'Restore purchases',
              style: TextStyle(
                color: AppTheme.ghostSilver.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(
                child: DuoButton(
                  onPressed: widget.onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  sfxType: DuoSfxType.negative,
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DuoButton(
                  onPressed: _busy ? null : widget.onNext,
                  dimOnDisabled: true,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  sfxType: DuoSfxType.positive,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: cs.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

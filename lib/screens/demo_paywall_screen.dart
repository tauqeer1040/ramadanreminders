import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Display-only fallback paywall shown when the RevenueCat offering can't
/// load (e.g. Error 23: no Test Store products in the dashboard). Clearly
/// labeled DEMO — purchases here do nothing. Remove once the dashboard
/// offering is healthy; [RevenueCatService.presentPaywall] routes here
/// automatically on [PaywallResult.error].
class DemoPaywallScreen extends StatelessWidget {
  final bool displayCloseButton;
  const DemoPaywallScreen({super.key, this.displayCloseButton = true});

  static const _packages = <Map<String, String>>[
    {'name': 'Weekly', 'price': '\$4.99 / week', 'blurb': 'Flexible, cancel anytime'},
    {'name': 'Monthly', 'price': '\$14.99 / month', 'blurb': 'Most flexible plan'},
    {'name': 'Annual', 'price': '\$99.99 / year', 'blurb': 'Best value — save 44%'},
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFF14101F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: displayCloseButton
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () =>
                    Navigator.of(context).pop(PaywallResult.cancelled),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Meowmin Max',
                style: tt.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Unlimited journaling, AI insights & streak shields.',
                style: tt.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'DEMO paywall — RevenueCat offering unavailable (Error 23). '
                  'Add Test Store products in the dashboard for live purchases.',
                  style: tt.labelSmall?.copyWith(color: Colors.amber),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              for (final p in _packages) ...[
                _DemoPackageCard(
                  name: p['name']!,
                  price: p['price']!,
                  blurb: p['blurb']!,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demo only — no purchase was made.'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              Text(
                'Cancel anytime. Managed via Google Play when live.',
                style: tt.labelSmall?.copyWith(color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoPackageCard extends StatelessWidget {
  final String name;
  final String price;
  final String blurb;
  final VoidCallback onTap;
  const _DemoPackageCard({
    required this.name,
    required this.price,
    required this.blurb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                  Text(blurb,
                      style:
                          tt.bodySmall?.copyWith(color: Colors.white60)),
                ],
              ),
            ),
            Text(price,
                style: tt.titleMedium?.copyWith(
                    color: const Color(0xFFFFD54F),
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

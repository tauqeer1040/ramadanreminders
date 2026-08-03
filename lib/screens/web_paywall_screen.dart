import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ramadan_reflections/services/revenuecat_service.dart';
import '../theme/app_theme.dart';
import '../components/widgets/duo_button.dart';

/// Custom Flutter paywall used on the web, where RevenueCatUI is not
/// supported. Fetches the current offering and lists its packages, then
/// purchases directly through [RevenueCatService.purchasePackage].
class WebPaywallScreen extends StatefulWidget {
  final Offering? offering;
  final bool displayCloseButton;

  const WebPaywallScreen({
    super.key,
    this.offering,
    this.displayCloseButton = true,
  });

  @override
  State<WebPaywallScreen> createState() => _WebPaywallScreenState();
}

class _WebPaywallScreenState extends State<WebPaywallScreen> {
  Offering? _offering;
  Package? _selected;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Offering? offering = widget.offering;
      if (offering == null) {
        final offerings = await RevenueCatService.instance.getOfferings();
        offering = offerings?.current;
      }
      if (offering == null) {
        throw Exception('No offerings configured for this account yet.');
      }
      final loaded = offering;
      if (!mounted) return;
      setState(() {
        _offering = loaded;
        _selected = _defaultPackage(loaded);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Package? _defaultPackage(Offering offering) {
    for (final type in const [
      PackageType.annual,
      PackageType.monthly,
      PackageType.lifetime,
      PackageType.weekly,
    ]) {
      final match = offering.availablePackages
          .where((p) => p.packageType == type)
          .firstOrNull;
      if (match != null) return match;
    }
    return offering.availablePackages.firstOrNull;
  }

  Future<void> _purchase(Package package) async {
    if (_purchasing) return;
    setState(() {
      _purchasing = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await RevenueCatService.instance.purchasePackage(package);
      if (!mounted) return;
      Navigator.of(context).pop(PaywallResult.purchased);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final cancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      setState(() {
        _error = cancelled ? null : 'Purchase failed: ${e.message}';
      });
      if (cancelled) Navigator.of(context).pop(PaywallResult.cancelled);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    if (_purchasing) return;
    setState(() {
      _purchasing = true;
      _error = null;
    });
    HapticFeedback.lightImpact();
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      final isPro = RevenueCatService.instance.hasActiveEntitlement(info);
      if (isPro) {
        Navigator.of(context).pop(PaywallResult.restored);
      } else {
        setState(() => _error = 'No previous purchases found to restore.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  String _labelFor(PackageType type) {
    switch (type) {
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.sixMonth:
        return '6 Months';
      case PackageType.threeMonth:
        return '3 Months';
      case PackageType.twoMonth:
        return '2 Months';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      default:
        return 'Plan';
    }
  }

  String _perPeriod(Package p) {
    final period = p.storeProduct.subscriptionPeriod;
    if (period == null || period.isEmpty) return '';
    if (period.contains('Y') || period.contains('y')) return '/year';
    if (period.contains('M') || period.contains('m')) return '/month';
    if (period.contains('W') || period.contains('w')) return '/week';
    if (period.contains('D') || period.contains('d')) return '/day';
    return '';
  }

  String _badgeFor(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'BEST VALUE';
      case PackageType.lifetime:
        return 'UNLOCK FOREVER';
      default:
        return '';
    }
  }

  /// Returns the intro/trial copy for a package, e.g. "$1.00 for 3 days",
  /// or null when the product has no introductory price.
  String? _introLine(Package p) {
    final intro = p.storeProduct.introductoryPrice;
    if (intro == null || intro.period.isEmpty) return null;
    final units = intro.periodNumberOfUnits > 0 ? intro.periodNumberOfUnits : 1;
    final unitLabel = switch (intro.periodUnit) {
      PeriodUnit.day => units == 1 ? 'day' : 'days',
      PeriodUnit.week => units == 1 ? 'week' : 'weeks',
      PeriodUnit.month => units == 1 ? 'month' : 'months',
      PeriodUnit.year => units == 1 ? 'year' : 'years',
      _ => 'periods',
    };
    return '${intro.priceString} for $units $unitLabel';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Meowmin Pro',
                    style: tt.titleLarge?.copyWith(
                      color: AppTheme.starWhite,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  if (widget.displayCloseButton)
                    IconButton(
                      onPressed: () => Navigator.of(context)
                          .pop(PaywallResult.cancelled),
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.ghostSilver),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final tt = Theme.of(context).textTheme;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.neonPurple),
      );
    }

    if (_error != null && _offering == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF6D00), size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ghostSilver.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              DuoButton(
                onPressed: _init,
                backgroundColor: AppTheme.neonPurple,
                depthColor: const Color(0xFF6A00FF),
                radius: 16,
                height: 52,
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final offering = _offering!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Keep Meowmin Independent',
            style: tt.headlineSmall?.copyWith(
              color: AppTheme.starWhite,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ad-free, private, and beautifully built. Support a small team that keeps your spiritual journey yours.',
            style: TextStyle(
              color: AppTheme.ghostSilver.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (offering.availablePackages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No packages are available for this offering yet. Please try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ghostSilver.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            )
          else ...[
            ...offering.availablePackages.map((p) {
              final selected = _selected?.identifier == p.identifier;
              final badge = _badgeFor(p);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.neonPurple.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? AppTheme.neonPurple
                            : Colors.white.withValues(alpha: 0.1),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _labelFor(p.packageType),
                                    style: TextStyle(
                                      color: AppTheme.starWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (badge.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.starGold
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(
                                          color: AppTheme.starGold,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.storeProduct.priceString}${_perPeriod(p)}',
                                style: TextStyle(
                                  color: AppTheme.ghostSilver
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_introLine(p) case final intro?) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$intro, then ${p.storeProduct.priceString}',
                                  style: TextStyle(
                                    color: AppTheme.neonPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppTheme.neonPurple
                                  : AppTheme.ghostSilver
                                      .withValues(alpha: 0.4),
                              width: 2,
                            ),
                            color: selected
                                ? AppTheme.neonPurple
                                : Colors.transparent,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFF6D00),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: DuoButton(
                onPressed:
                    _selected == null || _purchasing ? null : () => _purchase(_selected!),
                backgroundColor: const Color(0xFF9D50FF),
                depthColor: const Color(0xFF6A00FF),
                radius: 16,
                dimOnDisabled: true,
                child: _purchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Your Journey',
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
              onPressed: _purchasing ? null : _restore,
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: AppTheme.ghostSilver.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _link(context, 'Terms', 'https://www.taucity.com/terms'),
                const SizedBox(width: 16),
                _link(context, 'Privacy', 'https://www.taucity.com/privacy'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _link(BuildContext context, String label, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.ghostSilver.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.ghostSilver.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

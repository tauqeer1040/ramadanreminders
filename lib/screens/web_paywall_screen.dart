import 'package:flutter/foundation.dart';
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
  int _page = 0; // 0 = overview, 1 = selected-plan inform

  // Live Paddle pri IDs mirrored from pricing.astro — used for web deep-link
  static const _priMap = {
    r'$rc_monthly': 'pri_01m1h2jbnv7d7xs7eb8a9bswav',
    r'$rc_three_month': 'pri_01m1h2jqbb7e3gjym5kqf88b54',
    r'$rc_annual': 'pri_01m1h2jqe88brc2grgnr20jv80',
    r'$rc_lifetime': 'pri_01m1h2jqghnv9yj6k50fqf0wtr',
    r'$rc_custom_streak_shield': 'pri_01m1h2jqjntx6pec1arz3fzw48',
  };

  String? _priForPackage(Package p) {
    final id = p.identifier;
    if (_priMap.containsKey(id)) return _priMap[id];
    final lower = id.toLowerCase();
    if (lower.contains('three_month') || lower.contains('quarterly')) return _priMap[r'$rc_three_month'];
    if (lower.contains('lifetime')) return _priMap[r'$rc_lifetime'];
    if (lower.contains('custom_streak') || lower.contains('shield')) return _priMap[r'$rc_custom_streak_shield'];
    if (p.packageType == PackageType.annual) return _priMap[r'$rc_annual'];
    if (p.packageType == PackageType.monthly) return _priMap[r'$rc_monthly'];
    return null;
  }

  Future<void> _continueToWeb(Package p) async {
    final pri = _priForPackage(p);
    if (pri == null) {
      setState(() => _error = 'No web price for this plan yet.');
      return;
    }
    final uri = Uri.parse('https://meowmin.taucity.xyz/pricing?price=$pri');
    HapticFeedback.mediumImpact();
    // Amazon-style new tab — keep app paywall behind
    await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

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

  String _labelFor(Package package) {
    final id = package.identifier.toLowerCase();
    if (id.contains('three_month') || id.contains('quarterly') || id.contains('four')) {
      return '4-Month Challenge';
    }
    switch (package.packageType) {
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.annual:
        return 'Yearly — Recommended';
      case PackageType.sixMonth:
        return '6 Months';
      case PackageType.threeMonth:
        return '4-Month Challenge';
      case PackageType.twoMonth:
        return '2 Months';
      case PackageType.monthly:
        return id.contains('challenge') ? 'Monthly — Starter' : 'Monthly';
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
        return '72 SHIELDS';
      case PackageType.lifetime:
        return '150 SHIELDS · 3 USERS';
      default:
        final id = p.identifier.toLowerCase();
        if (id.contains('three_month') || id.contains('quarterly')) return '18 SHIELDS';
        if (id.contains('monthly') && id.contains('challenge')) return '3 SHIELDS';
        if (id.contains('monthly')) return '3 SHIELDS';
        return '';
    }
  }

  int? _shieldCount(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 72;
      case PackageType.lifetime:
        return 150;
      default:
        final id = p.identifier.toLowerCase();
        if (id.contains('three_month') || id.contains('quarterly')) return 18;
        return 3;
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
                    'Meowmin Max',
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
    // Two-screen paywall: 0 = overview grid (mirrors /pricing), 1 = selected inform -> web
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _page == 0 ? _buildPage0(offering, tt) : _buildPage1(tt),
    );
  }

  // Screen 0: overview — mirrors pricing.astro #plans grid, no green trial (skip-for-now handles trial)
  Widget _buildPage0(Offering offering, TextTheme tt) {
    return SingleChildScrollView(
      key: const ValueKey('page0'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your plan',
            style: tt.headlineSmall?.copyWith(
              color: AppTheme.starWhite,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Unlimited when you need it — habit over burnout. All on meowmin.taucity.xyz via Paddle.',
            style: TextStyle(
              color: AppTheme.ghostSilver.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
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
          else
            ...offering.availablePackages.map((p) {
              // hide green trial not needed — pricing already shows trial separately, but keep all Max packages
              // Shield (custom) stays as last card
              final badge = _badgeFor(p);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selected = p;
                      _page = 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
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
                                    _labelFor(p),
                                    style: const TextStyle(
                                      color: AppTheme.starWhite,
                                      fontSize: 14,
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
                                const SizedBox(height: 3),
                                Text(
                                  '$intro, then ${p.storeProduct.priceString}',
                                  style: const TextStyle(
                                    color: AppTheme.neonPurple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (_shieldCount(p) case final shields?) ...[
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.shield_rounded, size: 13, color: AppTheme.starGold),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$shields shield${shields > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: AppTheme.starGold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.ghostSilver, size: 22),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 10),
          Text(
            'Tap a plan to see web billing details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _purchasing ? null : _restore,
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                color: AppTheme.ghostSilver.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Screen 1: selected plan inform — no FAQs, Continue opens Paddle in new tab
  Widget _buildPage1(TextTheme tt) {
    final p = _selected;
    if (p == null) return _buildPage0(_offering!, tt);
    final badge = _badgeFor(p);
    return SingleChildScrollView(
      key: const ValueKey('page1'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _page = 0),
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ghostSilver),
              ),
              Text('Back to plans', style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neonPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_labelFor(p), style: const TextStyle(color: AppTheme.starWhite, fontSize: 16, fontWeight: FontWeight.w900)),
                    if (badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.starGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                        child: Text(badge, style: const TextStyle(color: AppTheme.starGold, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text('${p.storeProduct.priceString}${_perPeriod(p)}', style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w700)),
                if (_introLine(p) case final intro?) ...[
                  const SizedBox(height: 4),
                  Text('$intro, then ${p.storeProduct.priceString}', style: const TextStyle(color: AppTheme.neonPurple, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 16, color: AppTheme.neonPurple),
                    const SizedBox(width: 6),
                    Text('Web billing via Paddle', style: TextStyle(color: AppTheme.starWhite.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You’ll pay securely on meowmin.taucity.xyz via Paddle.com Market Ltd (our Merchant of Record). You’ll see PADDLE.NET* MEOWMIN on your statement. Paddle handles VAT/GST, receipts, and 14-day refunds. Your Meowmin Max entitlement syncs via RevenueCat after Paddle confirms.',
                  style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.8), fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 10),
                Text('• Auto-renew until you cancel • Cancel in Profile → Manage Subscription or on the web', style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _link(context, 'Terms', 'https://www.taucity.com/terms'),
              const SizedBox(width: 16),
              _link(context, 'Privacy', 'https://www.taucity.com/privacy'),
            ],
          ),
          const SizedBox(height: 20),
          DuoButton(
            onPressed: () => kIsWeb ? _continueToWeb(p!) : _purchase(p!),
            backgroundColor: AppTheme.neonPurple,
            depthColor: const Color(0xFF6A00FF),
            radius: 16,
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(kIsWeb ? 'Continue to Secure Checkout' : 'Get Meowmin Max', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Icon(kIsWeb ? Icons.open_in_new_rounded : Icons.lock_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Opens in a new tab — Amazon-style', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.5), fontSize: 11)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 12, fontWeight: FontWeight.w600)),
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

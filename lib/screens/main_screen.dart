import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/homepage.dart';
import '../components/shop_screen.dart' deferred as shop_screen_lib;
import '../components/quranpage.dart' deferred as quranpage_lib;
import '../components/profilepage.dart' deferred as profilepage_lib;
import '../core/app_background.dart';
import '../components/widgets/max_welcome_sheet.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/local_trial_service.dart';
import '../services/revenuecat_service.dart';
import '../services/streak_gate.dart';
import '../theme/app_theme.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback? onReady;
  const MainScreen({this.onReady, super.key});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainScreenState>();
    state?.navigateToTab(index);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final int _shopRefresh = 0;
  final _homepageKey = GlobalKey<HomepageState>();
  late final PageController _pageController;
  StreamSubscription? _authSubscription;
  bool _paywallInFlight = false;
  bool _expiredLockOpen = false;
  DateTime? _pausedAt;

  final List<bool> _pageLoaded = [true, false, false, false];
  final List<bool> _pageLoading = [false, false, false, false];

  static const _tabNames = ['home', 'insights', 'shop', 'profile'];

  List<Widget> get _pages => [
    AppBackground(backgroundImage: 'assets/photos/elements/app_bg2.webp', child: Homepage(key: _homepageKey)),
    AppBackground(child: _buildDeferredTab(1, () => quranpage_lib.QuranPage())),
    AppBackground(child: _buildDeferredTab(2, () => shop_screen_lib.ShopScreen(key: ValueKey('shop_$_shopRefresh')))),
    AppBackground(child: _buildDeferredTab(3, () => profilepage_lib.ProfilePage1())),
  ];

  Widget _buildDeferredTab(int index, Widget Function() builder) {
    if (_pageLoaded[index]) return builder();
    if (_pageLoading[index]) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);
    _authSubscription = AuthService.userChanges.listen((user) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onReady?.call();
      // Catches purchases completed outside the app's paywall sheets
      // (web checkout, restores) plus store renewals staged behind our
      // back: shows the Max thank-you sheet once per purchase key.
      if (mounted) {
        try {
          await RevenueCatService.stageRenewalIfNeeded().timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          );
        } catch (_) {}
        if (!mounted) return;
        try {
          await MaxWelcomeSheet.showIfPending(context).timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track real backgrounding: the native paywall sheet dismissing also
    // delivers `resumed`, which must NOT count as bg->fg (relaunch loop).
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      final away = pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(pausedAt);
      debugPrint('[PaywallResume] resumed after ${away.inSeconds}s away');
      unawaited(_showPaywallOnResume(away));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    }
  }

  /// Resume gate: subscribed -> nothing (plus welcome catch-up);
  /// trial/grace active -> dismissable paywall ONLY after a real background
  /// stay + dismiss cooldown (a paywall dismiss itself resumes the activity,
  /// so uncapped-every-resume relaunches the sheet the instant it closes);
  /// past grace -> non-dismissable thank-you re-lock (can't loop).
  Future<void> _showPaywallOnResume(Duration away) async {
    if (!mounted || _paywallInFlight) return;
    _paywallInFlight = true;
    try {
      bool subscribed = false;
      try {
        subscribed = await RevenueCatService.instance.isSubscribed();
      } catch (_) {}
      try {
        await LocalTrialService.syncSubscriptionState(subscribed);
      } catch (_) {}
      if (!mounted) return;
      if (subscribed) {
        if (mounted) {
          try {
            await RevenueCatService.stageRenewalIfNeeded().timeout(
              const Duration(seconds: 4),
              onTimeout: () => false,
            );
          } catch (_) {}
          if (!mounted) return;
          try {
            await MaxWelcomeSheet.showIfPending(context).timeout(
              const Duration(seconds: 4),
              onTimeout: () => false,
            );
          } catch (_) {}
        }
        return;
      }
      // Never-subscribed + friend-boosted streak>3 → skip soft paywall
      // and fall through to the expired hard lock below.
      bool streakGate = false;
      try {
        streakGate = await StreakGate.shouldShowStreakGate();
      } catch (_) {}
      if (!mounted) return;
      final started = await LocalTrialService.hasStarted();
      // Streak gate fires even when no trial started yet (high streak,
      // never paid) — don't early-return on !started in that case.
      if (!started && !streakGate) return;
      final soft = await LocalTrialService.isSoftWindow();
      if (!mounted) return;
      if (soft && !streakGate) {
        // Anti-loop: the sheet's own dismiss resumes the activity. Skip
        // while a sheet is open or just closed; otherwise every real
        // bg->fg relaunch presents (no cooldown — cold boot already covers
        // first paint, relaunches cover the rest).
        if (LocalTrialService.sheetOpen) {
          debugPrint('[PaywallResume] skip soft paywall: sheet open');
          return;
        }
        final closedAt = LocalTrialService.lastSheetClosed;
        if (closedAt != null &&
            DateTime.now().difference(closedAt) <
                LocalTrialService.resumePostSheetGrace) {
          debugPrint('[PaywallResume] skip soft paywall: sheet just closed');
          return;
        }
        if (away < LocalTrialService.resumeMinBackground) {
          debugPrint(
            '[PaywallResume] skip soft paywall: away ${away.inSeconds}s '
            '< ${LocalTrialService.resumeMinBackground.inSeconds}s',
          );
          return;
        }
        // Don't pave over an open sheet (journal editor, share, etc.).
        if (mounted && ModalRoute.of(context)?.isCurrent != true) {
          debugPrint('[PaywallResume] skip soft paywall: modal open');
          return;
        }
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && uid.isNotEmpty) {
            await RevenueCatService.instance.identify(uid);
          }
        } catch (_) {}
        PaywallResult result;
        try {
          await LocalTrialService.notePaywallShown();
          debugPrint('[PaywallResume] presenting soft paywall');
          LocalTrialService.sheetOpen = true;
          try {
            result = await RevenueCatService.instance.presentPaywall(
              displayCloseButton: true,
            );
          } finally {
            LocalTrialService.sheetOpen = false;
            LocalTrialService.lastSheetClosed = DateTime.now();
          }
          debugPrint('[PaywallResume] soft paywall closed: $result');
        } catch (_) {
          return;
        }
        if ((result == PaywallResult.purchased ||
                result == PaywallResult.restored) &&
            mounted) {
          try {
            await RevenueCatService.instance.getCustomerInfo();
          } catch (_) {}
          await RevenueCatService.flagWelcomePending(
            forceShow: result == PaywallResult.restored,
          );
          if (!mounted) return;
          try {
            await MaxWelcomeSheet.showIfPending(context);
          } catch (_) {}
          if (mounted) setState(() {});
        }
        return;
      }
      // Past grace — hard lock with the thank-you wall, same chain as
      // splash. Non-dismissable so it can't loop; skip if already open.
      if (!mounted) return;
      if (_expiredLockOpen) {
        debugPrint('[PaywallResume] skip re-lock: already open');
        return;
      }
      _expiredLockOpen = true;
      debugPrint('[PaywallResume] presenting expired re-lock');
      LocalTrialService.sheetOpen = true;
      bool unlocked = false;
      try {
        unlocked = await MaxWelcomeSheet.showExpired(
          context,
          onGetMax: _launchResumeOfferChain,
        );
      } finally {
        LocalTrialService.sheetOpen = false;
        LocalTrialService.lastSheetClosed = DateTime.now();
      }
      _expiredLockOpen = false;
      debugPrint('[PaywallResume] expired lock closed: $unlocked');
      if (unlocked && mounted) {
        try {
          await MaxWelcomeSheet.showIfPending(context);
        } catch (_) {}
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      _paywallInFlight = false;
    }
  }

  /// Resume copy of the splash expired chain: default paywall first, then
  /// the $1 exit offer. Returns true when Max unlocks.
  Future<bool> _launchResumeOfferChain() async {
    try {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await RevenueCatService.instance.identify(uid);
        }
      } catch (_) {}
      var result = await RevenueCatService.instance.presentPaywall(
        displayCloseButton: true,
      );
      if (result != PaywallResult.purchased &&
          result != PaywallResult.restored) {
        try {
          result = await RevenueCatService.instance.presentExitOffer(
            displayCloseButton: true,
          );
        } catch (_) {}
      }
      if (!mounted) return false;
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        await RevenueCatService.instance.getCustomerInfo();
        await RevenueCatService.flagWelcomePending();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void navigateToTab(int index) {
    final clamped = index.clamp(0, _pageLoaded.length - 1);
    if (clamped < _tabNames.length) {
      AnalyticsService.instance.logTabViewed(_tabNames[clamped]);
    }
    if (!_pageLoaded[clamped]) {
      _loadTab(clamped);
    }
    setState(() => _selectedIndex = clamped);

    final distance = (_selectedIndex - (_pageController.page ?? _selectedIndex)).abs();
    if (distance > 1.5) {
      _pageController.jumpToPage(clamped);
    } else {
      _pageController.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  Future<void> _loadTab(int index) async {
    if (_pageLoading[index] || _pageLoaded[index]) return;
    setState(() => _pageLoading[index] = true);
    try {
      switch (index) {
        case 1:
          await quranpage_lib.loadLibrary();
          break;
        case 2:
          await shop_screen_lib.loadLibrary();
          break;
        case 3:
          await profilepage_lib.loadLibrary();
          break;
      }
      if (mounted) {
        setState(() {
          _pageLoading[index] = false;
          _pageLoaded[index] = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pageLoading[index] = false);
      debugPrint('[MainScreen] Failed to load tab $index: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _selectedIndex = index);
          },
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          indicatorColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
          animationDuration: const Duration(milliseconds: 400),
          selectedIndex: _selectedIndex.clamp(0, _buildNavBarItems(cs).length - 1),
          onDestinationSelected: (index) {
            HapticFeedback.lightImpact();
            navigateToTab(index);
          },
          destinations: _buildNavBarItems(cs),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Meowmin?'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

List<NavigationDestination> _buildNavBarItems(ColorScheme cs) {
  return [
    const NavigationDestination(
      icon: Icon(Icons.home_outlined, weight: 200),
      selectedIcon: Icon(Icons.home_outlined, weight: 200),
      label: "home",
    ),
    NavigationDestination(
      icon: ImageIcon(AssetImage('assets/photos/elements/icons8-cards-64.webp')),
      selectedIcon: ImageIcon(AssetImage('assets/photos/elements/icons8-cards-64.webp')),
      label: 'Insights',
    ),
    const NavigationDestination(
      icon: Icon(Icons.store_outlined, weight: 200),
      selectedIcon: Icon(Icons.store_outlined, weight: 200),
      label: "shop",
    ),
    NavigationDestination(
      icon: _ProfileTabIcon(selected: false, cs: cs),
      selectedIcon: _ProfileTabIcon(selected: true, cs: cs),
      label: 'profile',
    ),
  ];
}

class _ProfileTabIcon extends StatefulWidget {
  final bool selected;
  final ColorScheme cs;

  const _ProfileTabIcon({required this.selected, required this.cs});

  @override
  State<_ProfileTabIcon> createState() => _ProfileTabIconState();
}

class _ProfileTabIconState extends State<_ProfileTabIcon> {
  User? _user;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _sub = AuthService.userChanges.listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = AuthService.getPhotoUrl(_user);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      final size = widget.selected ? 28.0 : 24.0;
      final borderWidth = widget.selected ? 2.0 : 1.0;
      final borderColor = widget.selected ? AppTheme.neonPurple : AppTheme.ghostSilver;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipOval(
          child: Image.network(photoUrl, fit: BoxFit.cover),
        ),
      );
    }

    if (widget.selected) {
      return const Icon(Icons.person_rounded, color: AppTheme.neonPurple);
    }
    return const Icon(Icons.person_outline_rounded, color: AppTheme.ghostSilver);
  }
}

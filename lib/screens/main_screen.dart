import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/homepage.dart';
import '../components/shop_screen.dart' deferred as shop_screen_lib;
import '../components/quranpage.dart' deferred as quranpage_lib;
import '../components/profilepage.dart' deferred as profilepage_lib;
import '../core/app_background.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady?.call();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
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

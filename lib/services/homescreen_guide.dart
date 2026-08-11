import 'browser_detector.dart';

/// Browser-specific step-by-step instructions for adding Meowmin to home screen.
class HomescreenGuide {
  final String title;
  final String subtitle;
  final List<HomescreenStep> steps;

  /// Optional URL of a video tutorial, opened externally (iOS uses this
  /// because it can't install natively via beforeinstallprompt).
  final String? videoUrl;

  const HomescreenGuide._(
    this.title,
    this.subtitle,
    this.steps, {
    this.videoUrl,
  });

  /// Returns the best guide for the current browser.
  static HomescreenGuide forCurrentBrowser() {
    final info = BrowserDetector.info;

    if (info.isIOS) return _safariIOS;
    if (info.isAndroidChrome) return _chromeAndroid;
    if (info.isFirefox) return _firefox;
    if (info.isEdge) return _edge;
    if (info.isSamsung) return _samsung;
    if (info.isMobile) return _genericMobile;
    return _desktop;
  }

  static const _safariIOS = HomescreenGuide._(
    'Add to Home Screen (Safari)',
    'Open this page in Safari, then follow these steps:',
    [
      HomescreenStep(
        icon: '📤',
        title: 'Tap the Share button',
        description: 'The square icon with an arrow at the bottom of the screen.',
      ),
      HomescreenStep(
        icon: '➕',
        title: 'Tap "Add to Home Screen"',
        description: 'Scroll down in the share menu and select it.',
      ),
      HomescreenStep(
        icon: '✏️',
        title: 'Edit the name (optional)',
        description: 'You can rename it to "Meowmin" for a cleaner look.',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Tap "Add"',
        description: 'Top right corner. Meowmin will appear on your home screen!',
      ),
    ],
    videoUrl: 'https://youtube.com/shorts/La1ZRc73PwA',
  );

  static const _chromeAndroid = HomescreenGuide._(
    'Install App (Chrome)',
    'Tap the install button below, or follow these steps:',
    [
      HomescreenStep(
        icon: '⋮',
        title: 'Tap the three-dot menu',
        description: 'Top right corner of Chrome.',
      ),
      HomescreenStep(
        icon: '📱',
        title: 'Tap "Install and create shortcut"',
        description: 'Scroll down to the 4th option from the bottom of the menu.',
        imageAsset: 'assets/photos/elements/installpwa.png',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Confirm installation',
        description: 'Meowmin will appear in your app drawer and home screen!',
      ),
    ],
  );

  static const _firefox = HomescreenGuide._(
    'Add to Home Screen (Firefox)',
    'Follow these steps to install:',
    [
      HomescreenStep(
        icon: '⋮',
        title: 'Tap the three-dot menu',
        description: 'Top right corner of Firefox.',
      ),
      HomescreenStep(
        icon: '📱',
        title: 'Tap "Install"',
        description: 'Or "Add to Home Screen" — the icon appears in your app drawer.',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Confirm',
        description: 'Meowmin will launch full-screen from your home screen!',
      ),
    ],
  );

  static const _edge = HomescreenGuide._(
    'Install App (Edge)',
    'Follow these steps to install:',
    [
      HomescreenStep(
        icon: '🔗',
        title: 'Tap the address bar icon',
        description: 'A small monitor icon with a downward arrow, or use the menu.',
      ),
      HomescreenStep(
        icon: '📱',
        title: 'Tap "Install app"',
        description: 'Confirm the installation.',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Done!',
        description: 'Meowmin opens in its own window — like a native app!',
      ),
    ],
  );

  static const _samsung = HomescreenGuide._(
    'Install App (Samsung Internet)',
    'Follow these steps to install:',
    [
      HomescreenStep(
        icon: '📦',
        title: 'Look for the install banner',
        description: 'Samsung Internet often shows a banner at the bottom automatically.',
      ),
      HomescreenStep(
        icon: '⋮',
        title: 'Or tap the menu → "Add page to"',
        description: 'Select "Home screen" from the menu.',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Confirm',
        description: 'Meowmin will appear on your home screen!',
      ),
    ],
  );

  static const _genericMobile = HomescreenGuide._(
    'Add to Home Screen',
    'Use your browser\'s menu to install:',
    [
      HomescreenStep(
        icon: '⋮',
        title: 'Open browser menu',
        description: 'Look for three dots or a share icon.',
      ),
      HomescreenStep(
        icon: '📱',
        title: 'Tap "Add to Home Screen" or "Install"',
        description: 'The exact wording varies by browser.',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Confirm',
        description: 'Meowmin will appear on your home screen!',
      ),
    ],
  );

  static const _desktop = HomescreenGuide._(
    'Install App (Desktop)',
    'Install Meowmin as a standalone app on your computer:',
    [
      HomescreenStep(
        icon: '🔗',
        title: 'Look for the install icon',
        description: 'A small icon appears in the address bar (right side).',
      ),
      HomescreenStep(
        icon: '📱',
        title: 'Click "Install"',
        description: 'Or use the browser menu → "Install App".',
      ),
      HomescreenStep(
        icon: '✅',
        title: 'Done!',
        description: 'Meowmin opens in its own window. Find it in your Start Menu or Launchpad.',
      ),
    ],
  );
}

class HomescreenStep {
  final String icon;
  final String title;
  final String description;

  /// Optional PNG rendered as the step icon instead of the emoji [icon].
  /// Only used by the Chrome guide, since installpwa.png is Chrome-specific.
  final String? imageAsset;

  const HomescreenStep({
    required this.icon,
    required this.title,
    required this.description,
    this.imageAsset,
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart' deferred as iar;
import 'package:share_plus/share_plus.dart' deferred as share_plus;
import '../../../services/analytics_service.dart';
import '../../../services/growth_prompt_service.dart';
import '../../../services/invite_service.dart';
import '../../../theme/app_theme.dart';
import 'duo_button.dart';
import 'glass_container.dart';

/// Single rotating post-like action offered after a scratch-card like:
/// either a store review ask or an app share. Prompt policy (throttle,
/// rotation, snooze, 5-star stop) lives in [GrowthPromptService]; this
/// sheet only renders one action.
enum DelightAction { review, share }

Future<void> showDelightActionSheet(
  BuildContext context,
  DelightAction action,
) async {
  HapticFeedback.lightImpact();
  try {
    AnalyticsService.instance.logEvent(
      'delight_sheet_shown',
      params: {'action': action.name},
    );
  } catch (_) {}
  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => GlassContainer(
      sigmaX: 20,
      sigmaY: 20,
      tint: Colors.white.withValues(alpha: 0.05),
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      child: _DelightSheet(action: action),
    ),
  );
}

class _DelightSheet extends StatefulWidget {
  final DelightAction action;
  const _DelightSheet({required this.action});

  @override
  State<_DelightSheet> createState() => _DelightSheetState();
}

class _DelightSheetState extends State<_DelightSheet> {
  /// When true, the review action first asks "Enjoying Meowmin?" with
  /// Yes/No (same pattern as onboarding). Yes leads to an inline 5-star
  /// picker — Play never reports the rating back, so this is the only
  /// way to learn it. 4-5 stars fires the store flow and stops prompts
  /// permanently; 1-3 suppresses for 30 days; No dismisses the sheet.
  bool _askingEnjoy = false;
  bool _askingStars = false;
  bool _busy = false;

  bool get _isReview => widget.action == DelightAction.review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isReview ? 'Loving Meowmin?' : 'Share the barakah',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isReview
                  ? (_askingStars
                      ? 'Tap the stars to rate your experience.'
                      : _askingEnjoy
                          ? 'Are you enjoying Meowmin?'
                          : 'A quick rating helps more hearts find the Quran.')
                  : 'Invite a friend and shield each other\'s streaks.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_isReview && _askingStars)
              _StarPicker(
                enabled: !_busy,
                onRated: _onStarsRated,
              )
            else if (_isReview && _askingEnjoy) ...[
              DuoButton(
                onPressed: _busy
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _askingEnjoy = false;
                          _askingStars = true;
                        });
                      },
                backgroundColor: AppTheme.starGold,
                depthColor: const Color(0xFFD4A20C),
                radius: 16,
                height: 56,
                child: const Text(
                  'Yes, I love it! 😍',
                  style: TextStyle(
                    color: AppTheme.starWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await GrowthPromptService.recordReviewOffered();
                        try {
                          AnalyticsService.instance.logEvent(
                            'delight_sheet_not_enjoying',
                            params: {'action': 'review'},
                          );
                        } catch (_) {}
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Text(
                  'Not really',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ] else
              DuoButton(
                onPressed: _busy
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        if (_isReview) {
                          setState(() => _askingEnjoy = true);
                        } else {
                          await _doShare(context);
                        }
                      },
                backgroundColor:
                    _isReview ? AppTheme.starGold : const Color(0xFFE91E63),
                depthColor: _isReview
                    ? const Color(0xFFD4A20C)
                    : const Color(0xFFAD1457),
                radius: 16,
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isReview ? Icons.star_rounded : Icons.share_rounded,
                      color: AppTheme.starWhite,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isReview ? 'Leave a Review' : 'Share with a Friend',
                      style: const TextStyle(
                        color: AppTheme.starWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                try {
                  AnalyticsService.instance.logEvent(
                    'delight_sheet_dismissed',
                    params: {'action': widget.action.name},
                  );
                } catch (_) {}
                Navigator.of(context).pop();
              },
              child: Text(
                'Maybe later',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await GrowthPromptService.snooze(days: 7);
                      try {
                        AnalyticsService.instance.logEvent(
                          'delight_sheet_snoozed',
                          params: {'action': widget.action.name},
                        );
                      } catch (_) {}
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: Text(
                'Don\'t remind me for 7 days',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onStarsRated(int stars) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      AnalyticsService.instance.logEvent(
        'delight_sheet_stars',
        params: {'action': 'review', 'stars': stars.toString()},
      );
    } catch (_) {}
    if (stars >= 4) {
      await GrowthPromptService.recordHighRating();
      await _fireStoreReview();
    } else {
      // 1-3 stars: keep it in-house, thank them, and suppress review
      // prompts for 30 days. No support inbox exists in-app, so the
      // feedback lands in analytics with the star count.
      await GrowthPromptService.recordLowRating();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for the honesty — we\'ll keep improving.'),
          ),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _fireStoreReview() async {
    try {
      await iar.loadLibrary();
      final review = iar.InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review not available on this device.')),
        );
      }
      await GrowthPromptService.recordReviewOffered();
      try {
        AnalyticsService.instance.logEvent(
          'delight_sheet_action',
          params: {'action': 'review'},
        );
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _doShare(BuildContext context) async {
    try {
      await share_plus.loadLibrary();
      final url = await InviteService.buildInviteUrl() ??
          (kIsWeb
              ? 'https://meowmin.taucity.xyz'
              : 'https://play.google.com/store/apps/details?id=com.taucity.meowmin');
      share_plus.Share.share(
        '🌙 Join me on Meowmin and we\'ll shield each other\'s streaks! A beautiful journaling companion for your spiritual journey.\n\n$url',
      );
      await GrowthPromptService.recordShare();
      try {
        AnalyticsService.instance.logEvent(
          'delight_sheet_action',
          params: {'action': 'share'},
        );
      } catch (_) {}
    } catch (_) {}
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _StarPicker extends StatelessWidget {
  final bool enabled;
  final ValueChanged<int> onRated;
  const _StarPicker({required this.enabled, required this.onRated});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 1; i <= 5; i++)
          IconButton(
            onPressed: enabled ? () => onRated(i) : null,
            icon: const Icon(Icons.star_rounded),
            color: AppTheme.starGold,
            iconSize: 44,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}

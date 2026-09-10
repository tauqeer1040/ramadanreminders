import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/analytics_service.dart';
import '../../../services/story_share_service.dart';
import '../../../theme/app_theme.dart';
import 'duo_button.dart';
import 'glass_container.dart';

/// Bottom sheet offered after a screenshot or a like on an insight card:
/// share the rendered card image to Instagram / WhatsApp stories.
Future<void> showShareInsightSheet(
  BuildContext context, {
  required String imagePath,
  required String source, // 'screenshot' | 'like'
}) async {
  HapticFeedback.lightImpact();
  try {
    AnalyticsService.instance.logEvent(
      'share_sheet_shown',
      params: {'source': source},
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      child: _ShareInsightSheet(imagePath: imagePath, source: source),
    ),
  );
}

class _ShareInsightSheet extends StatefulWidget {
  final String imagePath;
  final String source;
  const _ShareInsightSheet({required this.imagePath, required this.source});

  @override
  State<_ShareInsightSheet> createState() => _ShareInsightSheetState();
}

class _ShareInsightSheetState extends State<_ShareInsightSheet> {
  bool _busy = false;

  Future<void> _share(String target, Future<bool> Function() attempt) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await attempt();
      try {
        AnalyticsService.instance.logEvent(
          'share_sheet_action',
          params: {
            'source': widget.source,
            'target': target,
            'ok': ok.toString(),
          },
        );
      } catch (_) {}
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else if (target == 'more') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing failed — try again.')),
        );
      } else {
        // Direct story target unavailable: fall back to the system sheet
        // with the same image so sharing always completes.
        try {
          await StoryShareService.shareSystem(
            widget.imagePath,
            text: 'A reflection from my Meowmin journal 🌙',
          );
          if (mounted) Navigator.of(context).pop();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing failed — try again.')),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
              'Share this insight',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Spread the barakah — post it to your story.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            DuoButton(
              onPressed: _busy
                  ? null
                  : () => _share(
                      'instagram',
                      () => StoryShareService.shareInstagramStory(
                        widget.imagePath,
                      ),
                    ),
              backgroundColor: const Color(0xFFE91E63),
              depthColor: const Color(0xFFAD1457),
              radius: 16,
              height: 56,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.starWhite,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Instagram Story',
                    style: TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DuoButton(
              onPressed: _busy
                  ? null
                  : () => _share(
                      'whatsapp',
                      () => StoryShareService.shareWhatsappStatus(
                        widget.imagePath,
                      ),
                    ),
              backgroundColor: const Color(0xFF25D366),
              depthColor: const Color(0xFF1DA851),
              radius: 16,
              height: 56,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'WhatsApp Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DuoButton(
              onPressed: _busy
                  ? null
                  : () => _share('more', () async {
                      await StoryShareService.shareSystem(
                        widget.imagePath,
                        text: 'A reflection from my Meowmin journal 🌙',
                      );
                      return true;
                    }),
              backgroundColor: const Color(0xFF5E35B1),
              depthColor: const Color(0xFF4527A0),
              radius: 16,
              height: 56,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ios_share_rounded, color: AppTheme.starWhite, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'share',
                    style: TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

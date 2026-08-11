import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/homescreen_guide.dart';
import '../../services/pwa_install_service.dart';
import '../../theme/app_theme.dart';
import 'duo_button.dart';

/// Shows browser-specific step-by-step instructions for adding Meowmin
/// to the home screen.
Future<void> showPwaInstallDialog(BuildContext context) async {
  final guide = HomescreenGuide.forCurrentBrowser();
  final canNative = PwaInstallService.canInstall;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _InstallSheet(guide: guide, canNative: canNative),
  );
}

class _InstallSheet extends StatelessWidget {
  final HomescreenGuide guide;
  final bool canNative;

  const _InstallSheet({required this.guide, required this.canNative});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1025),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppTheme.ghostSilver.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.add_to_home_screen_rounded, color: AppTheme.neonPurple, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.title,
                          style: const TextStyle(
                            color: AppTheme.starWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.subtitle,
                          style: TextStyle(
                            color: AppTheme.ghostSilver.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Video tutorial button (iOS only — opens externally in the
            // YouTube app / Safari, which is far more reliable than an
            // inline player inside an iOS PWA).
            if (guide.videoUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: DuoButton(
                  onPressed: () async {
                    final url = Uri.parse(guide.videoUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  backgroundColor: AppTheme.neonPurple,
                  depthColor: const Color(0xFF6A00FF),
                  radius: 16,
                  height: 52,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: AppTheme.starWhite, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Watch tutorial',
                        style: TextStyle(
                          color: AppTheme.starWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Steps
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: guide.steps.length,
                itemBuilder: (ctx, i) {
                  final step = guide.steps[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step number circle
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.neonPurple.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: step.imageAsset != null
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    step.imageAsset!,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Text(
                                  step.icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: const TextStyle(
                                  color: AppTheme.starWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                step.description,
                                style: TextStyle(
                                  color: AppTheme.ghostSilver.withOpacity(0.7),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Native install button (if available)
            if (canNative)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: DuoButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await PwaInstallService.promptInstall();
                  },
                  backgroundColor: AppTheme.neonPurple,
                  depthColor: const Color(0xFF6A00FF),
                  radius: 16,
                  height: 56,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.install_mobile_rounded, color: AppTheme.starWhite, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Install Now',
                        style: TextStyle(
                          color: AppTheme.starWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!canNative)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'Follow the steps above to add Meowmin to your home screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ghostSilver.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

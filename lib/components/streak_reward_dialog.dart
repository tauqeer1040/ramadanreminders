import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scratcher/scratcher.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../services/shop_service.dart';
import '../services/streak_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_urls.dart';

Future<void> showStreakRewardDialog(BuildContext context) async {
  final streak = await StreakService.getStreak();
  if (!context.mounted) return;

  final random = Random();
  final scratchCardId = 13 + random.nextInt(9); // shop_13 to shop_21
  final prizeId = 1 + random.nextInt(12); // shop_1 to shop_12 (flower)
  final scratchCardUrl = shopFullUrl(scratchCardId);
  final prizeUrl = shopFullUrl(prizeId);
  final ctrl = ConfettiController();

  await ShopService.unlockItem('shop_$scratchCardId');

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 300,
          height: 440,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2D1B69), Color(0xFF1A1A2E)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$streak-Day Streak!',
                          style: const TextStyle(
                            color: AppTheme.starGold,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You unlocked a reward',
                          style: TextStyle(
                            color: AppTheme.starWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A2E),
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 220,
                            height: 260,
                            child: Stack(
                              children: [
                                prizeUrl.startsWith('assets/')
                                    ? Image.asset(prizeUrl, fit: BoxFit.cover)
                                    : Image.network(prizeUrl, fit: BoxFit.cover),
                                IgnorePointer(
                                  child: Confetti(
                                    controller: ctrl,
                                    options: const ConfettiOptions(
                                      particleCount: 80,
                                      spread: 360,
                                      startVelocity: 25,
                                      gravity: 0.4,
                                      colors: [Colors.amber, Colors.pink, Colors.cyan, Colors.white],
                                    ),
                                  ),
                                ),
                                Scratcher(
                                  brushSize: 35,
                                  threshold: 40,
                                  onThreshold: () {
                                    ctrl.launch();
                                    HapticFeedback.heavyImpact();
                                  },
                                  image: scratchCardUrl.startsWith('assets/')
                                      ? Image.asset(scratchCardUrl, fit: BoxFit.cover)
                                      : Image.network(scratchCardUrl, fit: BoxFit.cover),
                                  child: Container(color: Colors.transparent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A2E),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          ctrl.kill();
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.neonPurple.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.starWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Claimed!', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    ctrl.kill();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ctrl.kill();
}

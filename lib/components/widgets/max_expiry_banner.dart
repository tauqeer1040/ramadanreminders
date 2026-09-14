import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/max_status.dart';
import '../../theme/app_theme.dart';

/// "Max expiring in N days, please renew" — shown ONLY while the membership
/// is active but inside the 3-day expiry window (all paid tenures, including
/// cancelled-but-still-active). All Get Max buttons stay hidden; this banner
/// is the single renewal surface.
class MaxExpiryBanner extends StatelessWidget {
  final MaxStatus status;
  final VoidCallback onRenew;

  const MaxExpiryBanner({
    super.key,
    required this.status,
    required this.onRenew,
  });

  @override
  Widget build(BuildContext context) {
    if (!status.showExpiryBanner) return const SizedBox.shrink();
    final n = status.daysRemaining;
    final label = n <= 1
        ? 'Max expiring tomorrow — please renew'
        : 'Max expiring in $n days — please renew';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onRenew();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.starGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.starGold.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: AppTheme.starGold,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.starGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.starGold,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

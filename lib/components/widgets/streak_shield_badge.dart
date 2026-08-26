import 'package:flutter/material.dart';
import '../../services/invite_service.dart';
import '../../theme/app_theme.dart';

/// Small badge shown under a streak when a friend's higher streak is
/// shielding the user's own. Only renders when a friend is linked.
class StreakShieldBadge extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const StreakShieldBadge({super.key, this.padding = const EdgeInsets.only(top: 8)});

  @override
  State<StreakShieldBadge> createState() => _StreakShieldBadgeState();
}

class _StreakShieldBadgeState extends State<StreakShieldBadge> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String?> _load() async {
    if (!await InviteService.isFriendLinked()) return null;
    return InviteService.getFriendLabel();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final label = snap.data;
        if (label == null || label.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: widget.padding,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.neonPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.neonPurple.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, size: 14, color: AppTheme.neonPurple),
                const SizedBox(width: 6),
                Text(
                  'Shielded by $label',
                  style: const TextStyle(
                    color: AppTheme.starWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

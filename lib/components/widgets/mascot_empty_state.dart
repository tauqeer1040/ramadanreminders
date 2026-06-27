import 'package:flutter/material.dart';
import 'duo_button.dart';

class MascotEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double mascotSize;

  const MascotEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.mascotSize = 120,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: Image.asset(
                'assets/photos/mascot/hi.webp',
                width: mascotSize,
                height: mascotSize,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              DuoButton(
                onPressed: onAction!,
                backgroundColor: cs.primary,
                depthColor: cs.primary.withValues(alpha: 0.6),
                height: 48,
                radius: 14,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

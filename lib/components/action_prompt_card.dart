import 'package:flutter/material.dart';

class ActionPromptCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;

  const ActionPromptCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: foregroundColor,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: foregroundColor,
                    foregroundColor: backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: icon),
        ],
      ),
    );
  }
}

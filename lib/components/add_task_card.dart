import 'package:flutter/material.dart';

/// Trailing card in the tasks carousel — tap to add a new task.
class AddTaskCard extends StatelessWidget {
  const AddTaskCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          // border: Border.all(color: cs.outlineVariant, width: 2),
          // boxShadow: [
          //   BoxShadow(
          //     color: cs.shadow.withValues(alpha: 0.06),
          //     blurRadius: 12,
          //     offset: const Offset(0, 4),
          //   ),
          // ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: Icon(Icons.add_rounded, size: 22, color: cs.primary),
              ),
              const SizedBox(height: 10),
              Text(
                'Add Task',
                style: tt.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

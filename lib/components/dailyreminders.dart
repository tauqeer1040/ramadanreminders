import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class Reminder {
  final String id;
  final String type;
  final String content;
  final String? arabic;

  Reminder({
    required this.id,
    required this.type,
    required this.content,
    this.arabic,
  });
}

class DailyReminder extends StatelessWidget {
  DailyReminder({super.key});

  final List<Reminder> reminders = [
    Reminder(
      id: "1",
      type: "tesbiyat",
      content: "Glory be to Allah",
      arabic: "سُبْحَانَ اللّٰهِ",
    ),
    Reminder(
      id: "2",
      type: "verse",
      content: "Indeed, with hardship comes ease. (94:6)",
      arabic: "إِنَّ مَعَ الْعُسْرِ يُسْرًا",
    ),
    Reminder(
      id: "3",
      type: "dhikr",
      content: "There is no power except with Allah",
      arabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللّٰهِ",
    ),
  ];

  IconData _getIcon(String type) {
    switch (type) {
      case 'tesbiyat':
        return Icons.star;
      case 'verse':
        return Icons.menu_book;
      case 'dhikr':
        return Icons.favorite;
      default:
        return Icons.circle;
    }
  }

  String _getLabel(String type) {
    switch (type) {
      case 'tesbiyat':
        return 'Tesbiyat';
      case 'verse':
        return 'Quran';
      case 'dhikr':
        return 'Dhikr';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Daily Reminders",
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          ...reminders.map((r) => _buildReminderCard(context, r)),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Reminder reminder) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (reminder.type == 'tesbiyat' || reminder.type == 'dhikr') {
          Material3BottomNav.switchTab(context, 1); // Index 1 is Tasbih
        } else if (reminder.type == 'verse') {
          Material3BottomNav.switchTab(context, 2); // Index 2 is Quran
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIcon(reminder.type),
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _getLabel(reminder.type).toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            if (reminder.arabic != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  reminder.arabic!,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              reminder.content,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

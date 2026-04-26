import 'package:flutter/material.dart';
import 'journal_list_screen.dart';
import 'journal_editor_screen.dart';
import '../services/journal_service.dart';

class JournalSection extends StatelessWidget {
  const JournalSection({super.key});

  void _openEditor(BuildContext context) async {
    // 1. Check Guest Limits securely before pushing
    final limitReached = await JournalService.isGuestLimitReached();
    
    if (limitReached && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Free Trial limit reached! Tap your Profile to sign up securely and unlock unlimited journals."),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JournalListScreen()),
    );
    Future.microtask(() {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const JournalEditorScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: GestureDetector(
        onTap: () => _openEditor(context),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(
              2,
            ), // Very slight rounding like mockup
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "New",
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Create new journal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFFE8D5D5,
                  ), // Slightly rosy tint from mockup
                  border: Border.all(color: Colors.black87, width: 2.5),
                ),
                child: const Icon(Icons.add, color: Colors.black87, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

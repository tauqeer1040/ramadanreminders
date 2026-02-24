import 'package:flutter/material.dart';
import '../model/dhikr_item.dart';

/// A dialog for adding a new dhikr or editing an existing one.
///
/// Returns `null` if the user cancels, or a record `(name, target)` on save.
Future<({String name, int target})?> showDhikrDialog(
  BuildContext context, {
  DhikrItem? existing,
}) async {
  bool isCustomMode = existing != null;
  final nameController = TextEditingController(text: existing?.name ?? '');
  final targetController = TextEditingController(
    text: existing?.target.toString() ?? '33',
  );

  final popularDhikrs = [
    'SubhanAllah',
    'Alhamdulillah',
    'Allahu Akbar',
    'Astaghfirullah',
    'La ilaha illallah',
    'La hawla wa la quwwata',
    'SubhanAllahi wa bihamdihi',
    'SubhanAllahil Azeem',
    'Hasbunallah',
    'Salawat (Durood)',
  ];

  return await showDialog<({String name, int target})>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          if (!isCustomMode) {
            return AlertDialog(
              title: const Text('Add Tasbih'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...popularDhikrs.map((dhikr) {
                      return ActionChip(
                        label: Text(dhikr),
                        onPressed: () {
                          Navigator.pop(context, (name: dhikr, target: 33));
                        },
                      );
                    }),
                    ActionChip(
                      label: const Text(
                        'Custom +',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      onPressed: () {
                        setState(() {
                          isCustomMode = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(existing == null ? 'Custom Tasbih' : 'Edit Tasbih'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (e.g. SubhanAllah)',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target Count',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final target = int.tryParse(targetController.text) ?? 33;
                  if (name.isNotEmpty) {
                    Navigator.pop(context, (name: name, target: target));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

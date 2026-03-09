import 'dart:async';
import 'package:flutter/material.dart';
import '../services/journal_service.dart';

class JournalSection extends StatefulWidget {
  const JournalSection({super.key});

  @override
  State<JournalSection> createState() => _JournalSectionState();
}

class _JournalSectionState extends State<JournalSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadTodayJournal();
  }

  Future<void> _loadTodayJournal() async {
    final text = await JournalService.getTodayLocalJournal();
    if (text != null && text.isNotEmpty) {
      if (mounted) {
        setState(() {
          _controller.text = text;
        });
      }
    }
  }

  Future<void> _onTextChanged(String text) async {
    if (mounted) {
      setState(() => _isSaving = true);
    }

    // Aggressive offline save on every keystroke
    await JournalService.saveLocalJournal(text);

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _syncToCloud() async {
    if (mounted) setState(() => _isSyncing = true);

    await JournalService.syncJournalToCloud();

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Journal synced to cloud!')));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Write today's Journal",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "the AI will suggest an aayah tomorrow based on it for you to reflect on.",
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_isSaving)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    ),
                  IconButton(
                    onPressed: _isSyncing ? null : _syncToCloud,
                    icon: _isSyncing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Icon(Icons.cloud_upload_rounded, color: cs.primary),
                    tooltip: 'Sync to Cloud',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              maxLines: null,
              minLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 16, color: cs.onSurface, height: 1.5),
              decoration: InputDecoration(
                hintText:
                    "Write your thoughts, struggles, or gratitude here...",
                hintStyle: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                contentPadding: const EdgeInsets.all(20),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

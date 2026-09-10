import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/journal_service.dart';
import '../services/insight_service.dart';
import '../services/revenuecat_service.dart';
import '../services/moment_paywall_service.dart';
import '../core/app_background.dart';
import 'widgets/tweet_counter.dart';

class JournalEditorScreen extends StatefulWidget {
  final String? initialDate;
  final String? initialText;

  const JournalEditorScreen({super.key, this.initialDate, this.initialText});

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  static const int _maxChars = 280;

  late TextEditingController _controller;
  bool _isSaving = false;
  bool _showedLimitToast = false;
  // Max members write unlimited; everyone else is hard-capped at 280 chars.
  bool _isMax = false;
  // Generate a totally unique ID for new journals so users can create multiple per day
  late String _journalDate;

  List<InsightCard> _insightCards = [];
  bool _loadingInsights = false;
  JournalInsightStatus? _insightStatus;
  Timer? _saveTimer;
  Timer? _statusTimer;
  String _lastSavedText = '';
  int _statusPolls = 0;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _lastSavedText = widget.initialText ?? '';
    RevenueCatService.instance.isSubscribed().then((v) {
      if (mounted) setState(() => _isMax = v);
    }).catchError((_) {});

    // If no date passed, it's a completely new journal. Use precise timestamp as ID
    if (widget.initialDate == null) {
      _journalDate = DateTime.now().toIso8601String();
    } else {
      _journalDate = widget.initialDate!;
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    if (!mounted) return;
    setState(() => _loadingInsights = true);
    final status = await InsightService.fetchJournalInsightStatus(_journalDate);
    if (mounted) _applyStatus(status);
  }

  void _applyStatus(JournalInsightStatus status) {
    if (!mounted) return;
    _statusTimer?.cancel();
    setState(() {
      _insightStatus = status;
      _insightCards = status.cards;
      _loadingInsights = false;
    });
    // While Fanar is still brewing (or the fresh journal hasn't synced yet and
    // the status came back unknown with no cards), poll gently for ~5 minutes.
    final unknownEmpty = (status.aiStatus == null || status.aiStatus!.isEmpty) &&
        status.cards.isEmpty;
    if ((status.isPending || unknownEmpty) && _statusPolls < 20) {
      _statusPolls++;
      _statusTimer = Timer(const Duration(seconds: 15), () async {
        if (!mounted) return;
        final next = await InsightService.fetchJournalInsightStatus(_journalDate);
        _applyStatus(next);
      });
    }
  }

  void _onTextChanged(String text) {
    if (mounted) setState(() => _isSaving = true);

    // Show "write more with pro" hint when limit is first reached
    if (text.length >= _maxChars && !_showedLimitToast && mounted) {
      _showedLimitToast = true;
      HapticFeedback.lightImpact();
    }
    if (text.length < _maxChars) _showedLimitToast = false;

    // Debounced save: typing no longer hammers sync + AI reset on every
    // keystroke. The server also ignores identical content hashes, so only
    // real edits regenerate insights.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => _saveNow(text));
  }

  Future<void> _saveNow(String text) async {
    if (text == _lastSavedText) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    await JournalService.saveLocalJournalWithId(_journalDate, text);
    _lastSavedText = text;
    if (mounted) setState(() => _isSaving = false);
    // A real edit (re)starts the brew: reset polling and watch for new cards,
    // unless we already show cards for this exact save (they'll refresh).
    if (mounted && _insightCards.isEmpty) {
      _statusPolls = 0;
      final status = await InsightService.fetchJournalInsightStatus(_journalDate);
      _applyStatus(status);
    }
  }

  Future<void> _retryInsights() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final ok = await InsightService.retryFailedInsights();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (ok) {
      _statusPolls = 0;
      _loadInsights();
    }
  }

  @override
  void dispose() {
    // Flush any pending debounced save so no words are lost on back-nav.
    _saveTimer?.cancel();
    _statusTimer?.cancel();
    final pending = _controller.text;
    if (pending != _lastSavedText) {
      JournalService.saveLocalJournalWithId(_journalDate, pending);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () async {
            // Flush the save first (same as dispose would), then leave.
            _saveTimer?.cancel();
            final pending = _controller.text;
            if (pending != _lastSavedText) {
              await JournalService.saveLocalJournalWithId(_journalDate, pending);
              _lastSavedText = pending;
            }
            if (!mounted) return;
            // Capture the ROOT navigator before pop — the editor's context
            // dies on pop, the navigator doesn't.
            final rootNav = Navigator.of(context, rootNavigator: true);
            Navigator.of(context).pop();
            // Free users: paywall surfaces after writing (dismissable during
            // the 3-day trial, hard gate afterwards).
            MomentPaywallService.maybeShowOnNavigator(rootNav, moment: 'journal_saved');
          },
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AppBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              children: [
                Text(
                  widget.initialDate == null ? "New Journal" : JournalService.formatDisplayDate(_journalDate),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  onChanged: _onTextChanged,
                  autofocus: widget.initialDate == null, // Auto-focus if writing a new one
                  maxLines: null,
                  minLines: 6,
                  maxLength: _isMax ? null : _maxChars,
                  maxLengthEnforcement: _isMax
                      ? MaxLengthEnforcement.none
                      : MaxLengthEnforcement.enforced,
                  buildCounter: (context, {currentLength = 0, isFocused = false, maxLength = 280}) => null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 18,
                    color: cs.onSurface,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        "Write your thoughts, struggles, or gratitude here...",
                    hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                TweetCounter(
                  currentLength: _controller.text.length,
                  maxLength: _maxChars,
                ),
                _buildInsightsSection(cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsSection(ColorScheme cs) {
    if (_loadingInsights) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Preparing your AI insights...',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    if (_insightCards.isEmpty) {
      final status = _insightStatus;
      if (status != null && status.isFailed) {
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 16,
                  color: cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Insights hit a snag while brewing.',
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              TextButton(
                onPressed: _retrying ? null : _retryInsights,
                child: Text(_retrying ? 'Retrying…' : 'Retry'),
              ),
            ],
          ),
        );
      }
      if (status == null ||
          status.isPending ||
          ((status.aiStatus == null || status.aiStatus!.isEmpty))) {
        final queueNote = (status != null && status.queuePosition > 1)
            ? ' (#${status.queuePosition} in queue)'
            : '';
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Brewing your insights$queueNote — usually ready in a minute. Your deck queues behind today\u2019s cards.',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Your AI Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Personal insights from your journal entry.',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          ..._insightCards.asMap().entries.map((e) => _buildInsightBlock(e.key, e.value, cs)),
        ],
      ),
    );
  }

  Widget _buildInsightBlock(int index, InsightCard card, ColorScheme cs) {
    final String title;
    final List<String> paragraphs = [];

    switch (card.type) {
      case 'personalized_insight':
        title = 'A Surah for You';
        if (card.insight != null && card.insight!.trim().isNotEmpty) {
          paragraphs.add(card.insight!.trim());
        }
        if (card.quote != null && card.quote!.trim().isNotEmpty) {
          paragraphs.add('“${card.quote!.trim()}” — ${card.reference ?? ''}'.trim());
        }
      case 'surah_guidance':
        title = 'An Ayah to Hold Onto';
        if (card.explanation != null && card.explanation!.trim().isNotEmpty) {
          paragraphs.add(card.explanation!.trim());
        }
        if (card.reference != null && card.reference!.trim().isNotEmpty) {
          paragraphs.add('Qur\u2019an ${card.reference!.trim()}');
        }
      case 'story_and_task':
        title = 'A Story to Remember';
        if (card.story != null && card.story!.trim().isNotEmpty) {
          paragraphs.add(card.story!.trim());
        }
        if (card.lesson != null && card.lesson!.trim().isNotEmpty) {
          paragraphs.add(card.lesson!.trim());
        }
      default:
        title = 'Insight';
        if (card.insight != null && card.insight!.trim().isNotEmpty) {
          paragraphs.add(card.insight!.trim());
        }
    }

    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. $title',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

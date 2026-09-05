import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/analytics_service.dart';
import '../../services/email_continue_service.dart';
import '../../services/trial_service.dart';
import '../../core/app_background.dart';
import '../widgets/duo_button.dart';

/// Netflix-style "Check your email" finale for the email-continuation flow.
///
/// Soft mode (trial running): skippable via [onSkip].
/// Hard mode (trial expired): no skip — exits only via purchase detection
/// ([onUnlocked]), sign-in/restore (parent), resend/edit, or support.
/// Never renders purchase UI, prices, or checkout links (companion model).
class CheckEmailScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? snapshot;
  final bool hard;
  final VoidCallback onUnlocked;
  final VoidCallback? onSkip;

  /// Overrides the headline (default varies by [hard]). Used by the
  /// onboarding step-19 registration screen.
  final String? title;

  /// Overrides the skip button label (default "Continue without email…").
  final String? skipLabel;

  /// Hides the inline skip row so the host can render its own
  /// (e.g. bigger, pinned to the bottom).
  final bool hideSkip;

  const CheckEmailScreen({
    super.key,
    required this.email,
    required this.onUnlocked,
    this.snapshot,
    this.hard = false,
    this.onSkip,
    this.title,
    this.skipLabel,
    this.hideSkip = false,
  });

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  late String _email;
  bool _sending = true;
  String? _tok;
  bool _mailOpened = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _pollTimer;
  int _polls = 0;
  String _remainingLabel = '';
  static const int _maxPolls = 60; // 10 min @ 10s

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    try {
      AnalyticsService.instance.logEvent(
        widget.hard ? 'trial_expired_hard_gate' : 'email_check_shown',
      );
    } catch (_) {}
    _loadRemaining();
    _mint();
  }

  Future<void> _loadRemaining() async {
    try {
      final status = await TrialService.getStatus();
      if (!mounted) return;
      final days = status.daysRemaining;
      if (days > 1) {
        setState(() => _remainingLabel = '$days-days left');
        return;
      }
      if (days == 1) {
        setState(() => _remainingLabel = '1-day left');
        return;
      }
      final ms = status.graceMs;
      if (ms > 0) {
        final mins = ms ~/ 60000;
        setState(() {
          _remainingLabel = mins >= 60
              ? '${(mins / 60).floor()}h ${mins % 60}m left'
              : '${mins}m left';
        });
      }
    } catch (_) {}
  }

  Future<void> _mint() async {
    setState(() => _sending = true);
    final res = await EmailContinueService.mint(
      email: _email,
      snapshot: widget.snapshot,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _tok = res?['tok'] as String?;
    });
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _polls = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      _polls++;
      final tok = _tok ?? await EmailContinueService.storedTok();
      if (tok == null || tok.isEmpty) {
        if (_polls >= _maxPolls) _pollTimer?.cancel();
        return;
      }
      final st = await EmailContinueService.pollStatus(tok);
      if (!mounted) return;
      if (st?['purchased'] == true) {
        _pollTimer?.cancel();
        try {
          AnalyticsService.instance.logEvent('gate_unlocked_purchased');
        } catch (_) {}
        widget.onUnlocked();
      } else if (_polls >= _maxPolls) {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _openMail() async {
    HapticFeedback.mediumImpact();
    final opened = await EmailContinueService.openEmailApp();
    if (!mounted) return;
    setState(() => _mailOpened = opened);
    try {
      AnalyticsService.instance.logEvent('email_app_opened', params: {'opened': '$opened'});
    } catch (_) {}
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mail app found — try Resend email below.')),
      );
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendCooldown > 0) return;
    setState(() => _resending = true);
    final res = await EmailContinueService.resend(_email);
    if (!mounted) return;
    setState(() {
      _resending = false;
      final tok = res?['tok'] as String?;
      if (tok != null && tok.isNotEmpty) _tok = tok;
      _resendCooldown = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
    _startPolling();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res == null ? 'Resend failed — try again.' : 'Email re-sent — check inbox + spam.')),
    );
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (next != null && next.contains('@') && next != _email) {
      setState(() {
        _email = next;
        _tok = null;
      });
      await _mint();
    }
  }

  void _skip() {
    try {
      AnalyticsService.instance.logEvent('email_check_skipped');
    } catch (_) {}
    widget.onSkip?.call();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final masked = EmailContinueService.maskEmail(_email);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/photos/mascot/face.webp',
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.mark_email_read_rounded,
                      color: cs.primary,
                      size: 44,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: cs.surface,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Image.asset(
                          'assets/photos/elements/gmail_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.mark_email_read_rounded,
                            color: cs.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title ??
                (widget.hard
                    ? 'Your trial ended — check your email to continue'
                    : 'Check your email ✉️'),
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _sending
                ? 'Preparing your spiritual profile…'
                : 'We sent $masked a link with your spiritual profile card, '
                    'your first journal, and your AI insights.',
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          DuoButton(
            onPressed: _openMail,
            backgroundColor: cs.primary,
            depthColor: cs.primary.withValues(alpha: 0.8),
            radius: 16,
            height: 60,
            sfxType: DuoSfxType.positive,
            child: Text(
              'Open email app',
              style: TextStyle(fontSize: 18, color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: (_resending || _resendCooldown > 0) ? null : _resend,
                child: Text(_resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend email'),
              ),
              TextButton(onPressed: _editEmail, child: const Text('Edit email')),
            ],
          ),
          if (_mailOpened)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Waiting for registration… this screen unlocks automatically.',
                style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ),
          if (!widget.hideSkip && !widget.hard && widget.onSkip != null) ...[
            const SizedBox(height: 16),
            if (widget.skipLabel != null)
              TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  widget.skipLabel!,
                  style: tt.bodyMedium?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              DuoButton(
                onPressed: _skip,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
                height: 56,
                sfxType: DuoSfxType.positive,
                child: Text(
                  _remainingLabel.isEmpty
                      ? 'Continue without email'
                      : 'Continue without email — $_remainingLabel',
                  style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Scaffold wrapper for use as a standalone onboarding finale route.
class CheckEmailPage extends StatelessWidget {
  final String email;
  final Map<String, dynamic>? snapshot;
  final VoidCallback onSkip;
  final VoidCallback onUnlocked;

  const CheckEmailPage({
    super.key,
    required this.email,
    required this.onSkip,
    required this.onUnlocked,
    this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        backgroundImage: 'assets/photos/elements/onboarding.webp',
        overlayOpacity: 0.35,
        child: SafeArea(
          child: SingleChildScrollView(
            child: CheckEmailScreen(
              email: email,
              snapshot: snapshot,
              onSkip: onSkip,
              onUnlocked: onUnlocked,
            ),
          ),
        ),
      ),
    );
  }
}

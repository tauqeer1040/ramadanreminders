import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import '../services/auth_service.dart';
import '../services/journal_service.dart';
import '../services/dhikr_service.dart';

class ProfileBottomSheet extends StatefulWidget {
  const ProfileBottomSheet({super.key});

  @override
  State<ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<ProfileBottomSheet> {
  User? _user;
  int _totalTasbih = 0;
  bool _isSyncing = false;
  final DhikrService _dhikrService = DhikrService();

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await _dhikrService.loadTotalDhikrCount();
    if (mounted) {
      setState(() {
        _totalTasbih = count;
      });
    }
  }

  Future<void> _syncJournals() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    
    try {
      await JournalService.syncAllLocalJournalsToCloud();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: User Info
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primaryContainer,
                backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                child: _user?.photoURL == null 
                  ? Icon(Icons.person_rounded, size: 36, color: cs.onPrimaryContainer) 
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.displayName ?? (_user?.isAnonymous == true ? 'Guest User' : 'User'),
                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_user?.email != null)
                      Text(
                        _user!.email!,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Section
          Row(
            children: [
              _StatCard(
                label: 'Tasbih Count',
                value: _totalTasbih.toString(),
                icon: Icons.loop_rounded,
                color: Colors.teal,
              ),
              const SizedBox(width: 12),
              const _StatCard(
                label: 'Streak',
                value: '82 Days',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sync Section
          if (_user != null && !_user!.isAnonymous)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Journals', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          _isSyncing
                              ? 'Uploading your local reflections to Turso...'
                              : 'Upload your local reflections to Turso now',
                          style: tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isSyncing ? null : _syncJournals,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: ExpressiveLoadingIndicator(),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ],
              ),
            ),
          
          if (_user == null || _user!.isAnonymous == true)
            ActionChip(
              avatar: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in to sync your journals'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignInScreen())
                );
              },
            ),

          const SizedBox(height: 24),

          // Sign Out Button
          if (_user != null && !_user!.isAnonymous)
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService.signOut();
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

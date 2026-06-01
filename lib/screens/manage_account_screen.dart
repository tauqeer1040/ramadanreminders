import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../core/app_background.dart';
import '../components/widgets/duo_button.dart';

class ManageAccountScreen extends StatelessWidget {
  final User user;

  const ManageAccountScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Manage Account',
          style: TextStyle(
            color: AppTheme.starWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.starWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonPurple, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonPurple.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: user.photoURL != null
                        ? ClipOval(child: Image.network(user.photoURL!, fit: BoxFit.cover))
                        : Icon(Icons.person, size: 50, color: AppTheme.ghostSilver),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    user.email ?? '',
                    style: const TextStyle(
                      color: AppTheme.ghostSilver,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'ACCOUNT ACTIONS',
              style: TextStyle(
                color: AppTheme.ghostSilver,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              onPressed: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              backgroundColor: const Color(0xFF1E1E2E),
              depthColor: const Color(0xFF0D0D1A),
              height: 60,
              radius: 12,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text(
                      'Delete all data?',
                      style: TextStyle(color: AppTheme.starWhite),
                    ),
                    content: const Text(
                      'Your data will be kept for 30 days before permanent deletion. This cannot be undone.',
                      style: TextStyle(color: AppTheme.ghostSilver),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await UserService.deleteUserAccount(user);
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: const Text(
                          'DELETE',
                          style: TextStyle(color: Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: const Color(0xFF0D0D1A),
              depthColor: Colors.black,
              height: 60,
              radius: 12,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever_rounded, color: AppTheme.ghostSilver, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Delete My Account',
                    style: TextStyle(
                      color: AppTheme.ghostSilver,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

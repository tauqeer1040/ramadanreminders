import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class ProfilePage1 extends StatefulWidget {
  const ProfilePage1({super.key});

  @override
  State<ProfilePage1> createState() => _ProfilePage1State();
}

class _ProfilePage1State extends State<ProfilePage1> {
  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.currentUser;
    AuthService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? Your data will be kept for 30 days before permanent deletion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(context);
                if (_currentUser != null) {
                  setState(() => _isLoading = true);
                  try {
                    await UserService.deleteUserAccount(_currentUser!);
                    await AuthService.signOut();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to delete account. Please log out and log in again to verify your identity.',
                          ),
                        ),
                      );
                    }
                  }
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.38,
              child: _TopPortion(user: _currentUser),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    _currentUser != null
                        ? (_currentUser!.displayName ??
                              _currentUser!.email?.split('@')[0] ??
                              "User")
                        : "Guest User",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Authentication Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Account & Sync",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_currentUser == null) ...[
                              Text(
                                "Sign up to sync your badges, dhikrs, ayahs read, custom tasks, and easter eggs! Your data is never sold.",
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_isLoading)
                                const Center(child: CircularProgressIndicator())
                              else ...[
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => SignInScreen(
                                          actions: [
                                            AuthStateChangeAction<SignedIn>((
                                              context,
                                              state,
                                            ) {
                                              if (state.user != null) {
                                                UserService.syncUser(
                                                  state.user!,
                                                );
                                              }
                                              Navigator.of(context).pop();
                                            }),
                                            AuthStateChangeAction<UserCreated>((
                                              context,
                                              state,
                                            ) {
                                              if (state.credential.user !=
                                                  null) {
                                                UserService.syncUser(
                                                  state.credential.user!,
                                                );
                                              }
                                              Navigator.of(context).pop();
                                            }),
                                            AuthStateChangeAction<AuthFailed>((
                                              context,
                                              state,
                                            ) {
                                              print(
                                                "========= FIREBASE UI AUTH FAILED =========",
                                              );
                                              print(
                                                "Exception: ${state.exception}",
                                              );
                                              print("Is exception");
                                              if (state.exception
                                                  is PlatformException) {
                                                final pe =
                                                    state.exception
                                                        as PlatformException;
                                                print(
                                                  "PlatformCode: ${pe.code}",
                                                );
                                                print(
                                                  "PlatformMessage: ${pe.message}",
                                                );
                                                print(
                                                  "PlatformDetails: ${pe.details}",
                                                );
                                              } else if (state.exception
                                                  is FirebaseAuthException) {
                                                final fae =
                                                    state.exception
                                                        as FirebaseAuthException;
                                                print("AuthCode: ${fae.code}");
                                                print(
                                                  "AuthMessage: ${fae.message}",
                                                );
                                              }
                                              print(
                                                "===========================================",
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.login, size: 24),
                                  label: const Text("Login / Register"),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              Text(
                                "Signed in as ${_currentUser!.email}",
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  setState(() => _isLoading = true);
                                  await AuthService.signOut();
                                  if (mounted)
                                    setState(() => _isLoading = false);
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text("Sign Out"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.error,
                                  side: BorderSide(
                                    color: cs.error.withValues(alpha: 0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _showDeleteAccountDialog,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text("Delete Account"),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.error.withValues(alpha: 1),
                                  side: BorderSide(
                                    color: cs.error.withValues(alpha: 0.5),
                                  ),
                                  backgroundColor: Colors.transparent,
                                  // surfaceTintColor: cs.error
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const _ProfileInfoRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow();

  final List<ProfileInfoItem> _items = const [
    ProfileInfoItem("Posts", 900),
    ProfileInfoItem("Followers", 120),
    ProfileInfoItem("Following", 200),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items
            .map(
              (item) => Expanded(
                child: Row(
                  children: [
                    if (_items.indexOf(item) != 0) const VerticalDivider(),
                    Expanded(child: _singleItem(context, item)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _singleItem(BuildContext context, ProfileInfoItem item) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          item.value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      Text(item.title, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class ProfileInfoItem {
  final String title;
  final int value;
  const ProfileInfoItem(this.title, this.value);
}

class _TopPortion extends StatelessWidget {
  final User? user;
  const _TopPortion({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 50),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                      ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/photos/mascot/trophy.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: Container(
                      margin: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

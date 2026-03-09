import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection(
    'users',
  );

  /// Syncs user data to Firestore upon login.
  /// Creates a new document with default stats if it doesn't exist.
  /// Updates `lastLogin` and optionally `photoUrl` / `displayName` if it does.
  static Future<void> syncUser(User user) async {
    final docRef = _usersCollection.doc(user.uid);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      // Create new user document
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'photoUrl': user.photoURL ?? '',
        'subscriptionTier': 'free',
        'stats': {'ayahsRead': 0, 'tasksCompleted': 0, 'dhikrsCount': {}},
        'easterEggsUnlocked': [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing user document
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
        // Only override photoUrl/displayName if they exist on the Auth object and are different
        if (user.photoURL != null && user.photoURL!.isNotEmpty)
          'photoUrl': user.photoURL,
        if (user.displayName != null && user.displayName!.isNotEmpty)
          'displayName': user.displayName,
      });
    }
  }

  /// Get user data stream
  static Stream<DocumentSnapshot> getUserStream(String uid) {
    return _usersCollection.doc(uid).snapshots();
  }

  /// Archives user data and deletes the account.
  /// The user object will be deleted from Firebase Auth.
  static Future<void> deleteUserAccount(User user) async {
    final docRef = _usersCollection.doc(user.uid);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final userData = docSnapshot.data() as Map<String, dynamic>;

      final now = DateTime.now();
      userData['deletedAt'] = FieldValue.serverTimestamp();
      userData['scheduledForDeletionAt'] = Timestamp.fromDate(
        now.add(const Duration(days: 30)),
      );

      // Archive data
      await _firestore.collection('archived_users').doc(user.uid).set(userData);

      // Delete primary data
      await docRef.delete();
    }

    try {
      // Delete the Firebase Auth user
      await user.delete();
    } catch (e) {
      print("User deletion error: $e");
      rethrow;
    }
  }
}

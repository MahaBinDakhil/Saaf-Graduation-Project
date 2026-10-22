import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================

  Future<UserCredential> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Save the user's name in Firebase Authentication.
    if (credential.user != null && name.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(name.trim());
    }

    return credential;
  }

  // Alias in case your Create Account screen uses signUp()
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return createAccount(
      name: name,
      email: email,
      password: password,
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<UserCredential> logIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

       // ============================================================
     // GUEST
     // ============================================================

     /// Signs in without an email (Firebase Anonymous).
     Future<UserCredential> signInAsGuest() {
       return _auth.signInAnonymously();
     }
  /// True when the current user is a guest.
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;



  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

    // ============================================================
  // CURRENT USER & PROFILE
  // ============================================================

  // The logged-in user (null if nobody is logged in)
  User? get currentUser => _auth.currentUser;

  // Notifies whenever the user's profile changes (name, email, log out)
  Stream<User?> userChanges() => _auth.userChanges();

    Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());

    // Also update the name saved in Firestore.
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fullName': name.trim()}, SetOptions(merge: true));
  }

  // Sends a confirmation link to the new email.
  // The email only changes after the user opens the link.
  Future<void> updateEmail(String newEmail) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail.trim());
  }


  // Checks the current password, then changes it to the new one
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    // Firebase asks for the current password again before changing it
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }


  // Permanently deletes the logged-in user's account
    Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // 1. Delete all of the user's scans.
    final scans = await userDoc.collection('scans').get();
    for (final d in scans.docs) {
      await d.reference.delete();
    }

    // 2. Delete all chats and the messages inside each chat.
    final chats = await userDoc.collection('chats').get();
    for (final c in chats.docs) {
      final messages = await c.reference.collection('messages').get();
      for (final m in messages.docs) {
        await m.reference.delete();
      }
      await c.reference.delete();
    }

    // 3. Delete the user document, then the login account itself.
    await userDoc.delete();
    await user.delete();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logOut() async {
    await _auth.signOut();
  }

  // ============================================================
  // ERROR MESSAGES
  // ============================================================

  static String errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';

        case 'user-not-found':
          return 'No account was found with this email.';

        case 'wrong-password':
        case 'invalid-credential':
          return 'The email or password is incorrect.';

        case 'email-already-in-use':
          return 'An account already exists with this email.';

        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';

        case 'network-request-failed':
          return 'Please check your internet connection and try again.';

        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';

        case 'user-disabled':
          return 'This account has been disabled.';

        
        case 'requires-recent-login':
          return 'For your security, please log out, log in again, and try once more.';

        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
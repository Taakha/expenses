import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  static Future<void>? _googleInitialization;

  Stream<User?> get authChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String currencyCode,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'Firebase did not return the new user account.',
      );
    }
    await user.updateDisplayName(fullName.trim());
    await user.sendEmailVerification();
    await _saveProfile(
      uid: user.uid,
      fullName: fullName.trim(),
      email: user.email ?? email.trim(),
      phoneNumber: phoneNumber.trim(),
      currencyCode: currencyCode,
      isNew: true,
    );
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
    _googleInitialization ??= _googleSignIn.initialize();
    await _googleInitialization;
    final account = await _googleSignIn.authenticate();
    final tokens = account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await _saveProfile(
        uid: user.uid,
        fullName: user.displayName ?? '',
        email: user.email ?? '',
        phoneNumber: user.phoneNumber ?? '',
        currencyCode: 'UGX',
        isNew: result.additionalUserInfo?.isNewUser ?? false,
      );
    }
    return result;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleInitialization != null) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in account is required.');
    await user.updateDisplayName(fullName.trim());
    await _saveProfile(
      uid: user.uid,
      fullName: fullName.trim(),
      email: user.email ?? '',
      phoneNumber: phoneNumber.trim(),
      currencyCode: 'UGX',
    );
    await user.reload();
  }

  Future<void> changePassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in account is required.');
    await user.updatePassword(password);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in account is required.');
    await user.delete();
  }

  Future<void> _saveProfile({
    required String uid,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String currencyCode,
    bool isNew = false,
  }) async {
    final reference = _firestore.collection('users').doc(uid);
    await reference.set({
      'uid': uid,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      if (isNew) 'preferred_currency': currencyCode,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      if (isNew) 'created_at': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }
}

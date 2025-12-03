// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((authUser) async {
      if (authUser == null) return null;
      return await getUserById(authUser.uid);
    });
  }

  // Get current user
  User? get currentUser {
    final authUser = _auth.currentUser;
    return authUser != null ? _convertToUser(authUser) : null;
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = await getUserById(credential.user!.uid);
        // Check if user has admin privileges
        if (user != null && (user.role == UserRole.admin || user.role == UserRole.parkingOperator)) {
          return user;
        } else {
          await signOut();
          throw Exception('Access denied. Admin privileges required.');
        }
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create admin account (only for super admin)
  Future<User?> createAdminAccount({
    required String email,
    required String password,
    required String displayName,
    String? phoneNumber,
    UserRole role = UserRole.admin,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);

        // Create user document in Firestore
        final user = User(
          id: credential.user!.uid,
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber,
          role: role,
          isEmailVerified: credential.user!.emailVerified,
          isPhoneVerified: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(user.toMap());

        return user;
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  // Update user role (admin only)
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  // Convert Firebase User to our User model
  User _convertToUser(auth.User authUser) {
    return User(
      id: authUser.uid,
      email: authUser.email ?? '',
      displayName: authUser.displayName ?? '',
      photoURL: authUser.photoURL,
      isEmailVerified: authUser.emailVerified,
      createdAt: authUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Handle authentication exceptions
  String _handleAuthException(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}

// lib/providers/auth_provider.dart - Firebase Authentication state provider
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/database/database_service.dart';
import '../models/user.dart';

enum AuthStatus { initial, authenticating, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  User? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _error;
  String? _verificationId;
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Getters
  User? get user => _user;
  User? get currentUser => _user; // For backward compatibility
  AuthStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null && _status == AuthStatus.authenticated;
  String? get verificationId => _verificationId;

  // Initialize auth provider
  Future<void> initialize() async {
    _setLoading(true);
    
    try {
      // Listen to Firebase Auth state changes
      DatabaseService.auth.authStateChanges().listen(_onAuthStateChanged);
      
      // Check current user
      final firebaseUser = DatabaseService.auth.currentUser;
      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser.uid);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Handle Firebase Auth state changes
  Future<void> _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
    if (firebaseUser != null) {
      await _loadUserProfile(firebaseUser.uid);
    } else {
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      final userDoc = await DatabaseService.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        _user = User.fromFirestore(userDoc);
        _setStatus(AuthStatus.authenticated);
      } else {
        // Create user profile if it doesn't exist
        await _createUserProfile(uid);
      }
    } catch (e) {
      _setError('Failed to load user profile: $e');
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(String uid) async {
    try {
      final firebaseUser = DatabaseService.auth.currentUser!;
      
      final newUser = User(
        id: uid,
        email: firebaseUser.email ?? '',
        phoneNumber: firebaseUser.phoneNumber,
        displayName: firebaseUser.displayName ?? 'User',
        photoURL: firebaseUser.photoURL,
        role: UserRole.user,
        isEmailVerified: firebaseUser.emailVerified,
        isPhoneVerified: firebaseUser.phoneNumber != null,
      );

      await DatabaseService.collection('users').doc(uid).set(newUser.toMap());
      _user = newUser;
      _setStatus(AuthStatus.authenticated);
    } catch (e) {
      _setError('Failed to create user profile: $e');
    }
  }

  // Google Sign In
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        _setLoading(false);
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await DatabaseService.auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if user document exists, if not create one
        final userDoc = await DatabaseService.collection('users').doc(userCredential.user!.uid).get();
        
        if (!userDoc.exists) {
          // Create new user profile for Google sign-in
          final newUser = User(
            id: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            displayName: userCredential.user!.displayName ?? 'New User',
            photoURL: userCredential.user!.photoURL,
            role: UserRole.user,
            isEmailVerified: userCredential.user!.emailVerified,
            isPhoneVerified: false,
          );
          
          await DatabaseService.collection('users').doc(userCredential.user!.uid).set(newUser.toMap());
          _user = newUser;
        } else {
          _user = User.fromFirestore(userDoc);
        }
        
        _setStatus(AuthStatus.authenticated);
        return true;
      }
      
      return false;
    } catch (e) {
      _setError('Google Sign In failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    final firebaseUser = DatabaseService.auth.currentUser;
    if (firebaseUser == null) return false;

    try {
      await firebaseUser.sendEmailVerification();
      return true;
    } catch (e) {
      _setError('Failed to send email verification: $e');
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final credential = await DatabaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadUserProfile(credential.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      _setError('Sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Register with email and password only
  Future<bool> register(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final credential = await DatabaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create minimal user profile - additional details will be collected later
        final newUser = User(
          id: credential.user!.uid,
          email: email,
          displayName: 'New User', // Temporary name
          role: UserRole.user,
          isEmailVerified: false,
          isPhoneVerified: false,
        );

        await DatabaseService.collection('users').doc(credential.user!.uid).set(newUser.toMap());
        
        _user = newUser;
        _setStatus(AuthStatus.authenticated);
        
        // Send email verification
        try {
          await sendEmailVerification();
        } catch (e) {
          // Email verification failed, but registration succeeded
        }
        
        return true;
      }
      return false;
    } catch (e) {
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with credential
  Future<void> _signInWithCredential(firebase_auth.AuthCredential credential) async {
    try {
      final userCredential = await DatabaseService.auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _loadUserProfile(userCredential.user!.uid);
      }
    } catch (e) {
      _setError('Sign in failed: $e');
    }
  }

  // Check if user profile is complete
  bool get isProfileComplete {
    if (_user == null) return false;
    return _user!.displayName != 'New User' && 
           _user!.displayName.isNotEmpty && 
           _user!.phoneNumber != null && 
           _user!.phoneNumber!.isNotEmpty;
  }

  // Complete user profile with name and phone
  Future<bool> completeProfile({
    required String name,
    required String phoneNumber,
    String? city,
    String? emergencyContact,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _clearError();
    
    try {
      final updatedUser = _user!.copyWith(
        displayName: name,
        phoneNumber: phoneNumber,
        city: city,
        emergencyContact: emergencyContact,
      );

      await DatabaseService.collection('users').doc(_user!.id).update(updatedUser.toMap());
      
      _user = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to complete profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phoneNumber,
    String? city,
    String? emergencyContact,
    UserRole? role,
    Map<String, dynamic>? preferences,
    Map<String, double>? location,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    
    try {
      final updatedUser = _user!.copyWith(
        displayName: name,
        phoneNumber: phoneNumber,
        city: city,
        emergencyContact: emergencyContact,
        role: role,
        preferences: preferences,
        location: location,
      );

      await DatabaseService.collection('users').doc(_user!.id).update(updatedUser.toMap());
      
      _user = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final firebaseUser = DatabaseService.auth.currentUser;
    if (firebaseUser == null) return false;

    _setLoading(true);
    
    try {
      // Re-authenticate user
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      
      // Update password
      await firebaseUser.updatePassword(newPassword);
      
      return true;
    } catch (e) {
      _setError('Failed to change password: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await Future.wait([
        DatabaseService.auth.signOut(),
        _googleSignIn.signOut(), // Sign out from Google
      ]);
      
      _user = null;
      _verificationId = null;
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      _setError('Sign out failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    if (_user == null) return false;

    _setLoading(true);
    
    try {
      // Delete user data from Firestore
      await DatabaseService.collection('users').doc(_user!.id).delete();
      
      // Delete Firebase Auth account
      await DatabaseService.auth.currentUser?.delete();
      
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
      
      return true;
    } catch (e) {
      _setError('Failed to delete account: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await DatabaseService.auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _setError('Failed to send password reset email: $e');
      return false;
    }
  }

  // Helper methods
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.initial;
    }
    notifyListeners();
  }

  // Clear error manually
  void clearError() {
    _clearError();
  }
}

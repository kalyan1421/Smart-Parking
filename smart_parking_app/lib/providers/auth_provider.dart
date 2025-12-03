// lib/providers/auth_provider.dart - Firebase Authentication state provider
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      print('🧩 Phase1Audit: Auth initialize()');
      // Listen to Firebase Auth state changes
      DatabaseService.auth.authStateChanges().listen(_onAuthStateChanged);
      
      // Check current user
      final firebaseUser = DatabaseService.auth.currentUser;
      if (firebaseUser != null) {
        print('🧩 Phase1Audit: Firebase currentUser detected uid=${firebaseUser.uid}');
        await _loadUserProfile(firebaseUser.uid);
      } else {
        print('🧩 Phase1Audit: No currentUser, set unauthenticated');
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      print('🧩 Phase1Audit: Error initialize -> $e');
      _setError('Failed to initialize auth: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Handle Firebase Auth state changes
  Future<void> _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
    if (firebaseUser != null) {
      print('🧩 Phase1Audit: authStateChanged -> signed in uid=${firebaseUser.uid}');
      await _loadUserProfile(firebaseUser.uid);
    } else {
      print('🧩 Phase1Audit: authStateChanged -> signed out');
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      print('DEBUG: Loading user profile for UID: $uid');
      print('🧩 Phase1Audit: Loading user profile uid=$uid');
      final userDoc = await DatabaseService.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        print('DEBUG: User document exists, parsing...');
        print('DEBUG: Document data: ${userDoc.data()}');
        _user = User.fromFirestore(userDoc);
        _setStatus(AuthStatus.authenticated);
        
        // Cache user ID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', uid);
        print('DEBUG: User profile loaded successfully');
        print('🧩 Phase1Audit: User profile loaded uid=$uid');
      } else {
        print('DEBUG: User document does not exist, creating profile...');
        // Create user profile if it doesn't exist
        await _createUserProfile(uid);
      }
    } catch (e) {
      print('DEBUG: Error loading user profile: $e');
      print('DEBUG: Error stack trace: ${StackTrace.current}');
      print('🧩 Phase1Audit: Error _loadUserProfile -> $e');
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
        // createdAt: DateTime.now(),
        // updatedAt: DateTime.now(),
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
            // createdAt: DateTime.now(),
            // updatedAt: DateTime.now(),
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
      print('Google Sign-in error: $e');
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
      print('🧩 Phase1Audit: login email=$email');
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
      print('🧩 Phase1Audit: Error login -> $e');
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
      print('DEBUG: Starting registration for email: $email');
      print('🧩 Phase1Audit: register email=$email');
      final credential = await DatabaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        print('DEBUG: Firebase user created with UID: ${credential.user!.uid}');
        
        // Create minimal user profile - additional details will be collected later
        final newUser = User(
          id: credential.user!.uid,
          email: email,
          displayName: 'New User', // Temporary name
          role: UserRole.user,
          isEmailVerified: false,
          isPhoneVerified: false,
          // createdAt: DateTime.now(),
          // updatedAt: DateTime.now(),
        );

        print('DEBUG: Creating Firestore document...');
        print('DEBUG: User data to save: ${newUser.toMap()}');
        await DatabaseService.collection('users').doc(credential.user!.uid).set(newUser.toMap());
        print('DEBUG: Firestore document created successfully');
        
        _user = newUser;
        _setStatus(AuthStatus.authenticated);
        
        // Send email verification
        try {
          await sendEmailVerification();
          print('DEBUG: Email verification sent');
        } catch (e) {
          print('DEBUG: Failed to send email verification: $e');
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('DEBUG: Registration error: $e');
      print('DEBUG: Error stack trace: ${StackTrace.current}');
      print('🧩 Phase1Audit: Error register -> $e');
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
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _clearError();
    
    try {
      final updatedUser = _user!.copyWith(
        displayName: name,
        phoneNumber: phoneNumber,
        // updatedAt: DateTime.now(),
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
        role: role,
        preferences: preferences,
        location: location,
        //  updatedAt: DateTime.now(),
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
      print('🧩 Phase1Audit: logout');
      await Future.wait([
        DatabaseService.auth.signOut(),
        _googleSignIn.signOut(), // Sign out from Google
      ]);
      
      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      
      _user = null;
      _verificationId = null;
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      print('🧩 Phase1Audit: Error logout -> $e');
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
      
      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      
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

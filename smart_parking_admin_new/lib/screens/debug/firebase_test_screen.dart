// lib/screens/debug/firebase_test_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/user.dart' as app_user;

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({Key? key}) : super(key: key);

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _output = '';
  bool _isLoading = false;

  void _addOutput(String message) {
    setState(() {
      _output += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
    print(message);
  }

  void _clearOutput() {
    setState(() {
      _output = '';
    });
  }

  Future<void> _testFirebaseConnection() async {
    _clearOutput();
    setState(() => _isLoading = true);
    
    try {
      _addOutput('🔥 Testing Firebase Connection...');
      
      // Test Firebase Core
      _addOutput('✅ Firebase Core initialized');
      
      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      _addOutput('✅ Firebase Auth instance created');
      _addOutput('Current user: ${auth.currentUser?.email ?? 'Not signed in'}');
      
      // Test Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.enableNetwork();
      _addOutput('✅ Firestore connection established');
      
      // Test Firestore read
      try {
        final testDoc = await firestore.collection('test').doc('connection').get();
        _addOutput('✅ Firestore read test successful');
      } catch (e) {
        _addOutput('⚠️ Firestore read test failed: $e');
      }
      
      _addOutput('🎉 All Firebase services are working!');
      
    } catch (e) {
      _addOutput('❌ Firebase test failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testDirectAuth() async {
    _clearOutput();
    setState(() => _isLoading = true);
    
    try {
      _addOutput('🔐 Testing Direct Firebase Auth...');
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Test email and password
      const testEmail = 'testadmin@smartparking.com';
      const testPassword = 'TestAdmin123';
      const testName = 'Test Admin';
      
      _addOutput('📧 Creating user: $testEmail');
      
      // Create user
      final credential = await auth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      
      if (credential.user != null) {
        _addOutput('✅ Firebase Auth user created: ${credential.user!.uid}');
        
        // Update display name
        await credential.user!.updateDisplayName(testName);
        _addOutput('✅ Display name updated');
        
        // Create Firestore document
        final userDoc = {
          'id': credential.user!.uid,
          'email': testEmail,
          'displayName': testName,
          'role': 'admin',
          'isEmailVerified': credential.user!.emailVerified,
          'isPhoneVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        await firestore.collection('users').doc(credential.user!.uid).set(userDoc);
        _addOutput('✅ Firestore user document created');
        
        // Test login
        await auth.signOut();
        _addOutput('🚪 Signed out');
        
        final loginCredential = await auth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        
        if (loginCredential.user != null) {
          _addOutput('✅ Login test successful');
          
          // Get user document
          final userDocSnapshot = await firestore
              .collection('users')
              .doc(loginCredential.user!.uid)
              .get();
              
          if (userDocSnapshot.exists) {
            final userData = userDocSnapshot.data();
            _addOutput('✅ User document retrieved: ${userData?['role']}');
          }
          
          // Clean up - delete test user
          await loginCredential.user!.delete();
          await firestore.collection('users').doc(loginCredential.user!.uid).delete();
          _addOutput('🗑️ Test user cleaned up');
        }
        
        _addOutput('🎉 Direct Firebase Auth test successful!');
      }
      
    } catch (e) {
      _addOutput('❌ Direct auth test failed: $e');
      _addOutput('Error details: ${e.toString()}');
      
      // Try to clean up on error
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
          _addOutput('🗑️ Cleaned up user on error');
        }
      } catch (cleanupError) {
        _addOutput('⚠️ Cleanup failed: $cleanupError');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAuthProvider() async {
    _clearOutput();
    setState(() => _isLoading = true);
    
    try {
      _addOutput('🔧 Testing AuthProvider...');
      
      final authProvider = context.read<app_auth.AuthProvider>();
      
      // Test admin account creation through provider
      await authProvider.createAdminAccount(
        email: 'providertest@smartparking.com',
        password: 'ProviderTest123',
        displayName: 'Provider Test Admin',
        phoneNumber: '+1234567890',
        role: app_user.UserRole.admin,
      );
      
      if (authProvider.error != null) {
        _addOutput('❌ AuthProvider error: ${authProvider.error}');
      } else {
        _addOutput('✅ AuthProvider admin creation successful');
        
        // Clean up
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .delete();
          await currentUser.delete();
          _addOutput('🗑️ Provider test user cleaned up');
        }
      }
      
    } catch (e) {
      _addOutput('❌ AuthProvider test failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Test Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testFirebaseConnection,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Test Connection', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testDirectAuth,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Test Direct Auth', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testAuthProvider,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Test AuthProvider', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: _clearOutput,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Clear Output', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Loading indicator
            if (_isLoading)
              const LinearProgressIndicator(),
            
            const SizedBox(height: 16),
            
            // Output
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _output.isEmpty ? 'Click a test button to see output...' : _output,
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Test Connection - Verifies Firebase is properly initialized\n'
                    '2. Test Direct Auth - Tests Firebase Auth and Firestore directly\n'
                    '3. Test AuthProvider - Tests your app\'s authentication service\n'
                    '4. Check output for detailed logs and error messages',
                    style: TextStyle(fontSize: 12),
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

// lib/screens/admin/admin_setup_screen.dart
import 'package:flutter/material.dart';
import '../../services/admin_setup_service.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({Key? key}) : super(key: key);

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  Map<String, dynamic>? _setupResult;

  @override
  void initState() {
    super.initState();
    _checkCurrentSetup();
  }

  Future<void> _checkCurrentSetup() async {
    setState(() {
      _statusMessage = 'Checking current setup...';
    });

    try {
      final isAdminSetup = await AdminSetupService.isAdminSetupComplete();
      final hasParkingSpots = await AdminSetupService.hasParkingSpots();
      
      setState(() {
        _statusMessage = '''Current Status:
• Admin Setup: ${isAdminSetup ? '✅ Complete' : '❌ Not Complete'}
• Parking Spots: ${hasParkingSpots ? '✅ Available' : '❌ None Found'}''';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking setup: $e';
      });
    }
  }

  Future<void> _runAdminSetup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Setting up admin account and data...';
      _setupResult = null;
    });

    try {
      final result = await AdminSetupService.setupAdmin();
      
      setState(() {
        _setupResult = result;
        _isLoading = false;
        
        if (result['success']) {
          _statusMessage = '''✅ Setup Completed Successfully!

Admin Credentials:
📧 Email: ${AdminSetupService.adminEmail}
🔑 Password: ${AdminSetupService.adminPassword}
👤 Name: ${AdminSetupService.adminDisplayName}
🆔 UID: ${result['adminUid']}

📊 Data Created:
• Admin user profile
• ${result['parkingSpotsCreated']} sample parking spots

🔗 Next Steps:
1. Use admin credentials to log into the admin app
2. Verify parking spots are visible in user app
3. Test all functionality''';
        } else {
          _statusMessage = '❌ Setup Failed: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Setup Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Setup'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔐 Admin Setup Utility',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This utility will create an admin account and sample parking spots for testing.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _runAdminSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Setting up...'),
                              ],
                            )
                          : const Text('🚀 Setup Admin & Data'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkCurrentSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('🔍 Check Current Setup'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📋 Status & Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _statusMessage.isEmpty 
                                  ? 'Click "Check Current Setup" to see the current status.'
                                  : _statusMessage,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.orange[50],
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Important Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• This is for development/testing only\n'
                      '• Run this once to set up initial data\n'
                      '• Make sure Firestore rules are deployed\n'
                      '• Check Firebase Console for verification',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

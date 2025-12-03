// lib/screens/auth/complete_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/core/utils/validators.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class CompleteProfileScreen extends StatefulWidget {
  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.completeProfile(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 48,
                      color: Colors.blue[700],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Welcome to Smart Parking!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please complete your profile to get started',
                      style: TextStyle(
                        color: Colors.blue[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Error message
              if (authProvider.error != null)
                Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authProvider.error!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Profile completion form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textInputAction: TextInputAction.next,
                      validator: Validators.validateName,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Phone Number field
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: Validators.validatePhone,
                      onFieldSubmitted: (_) => _completeProfile(),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Complete Profile button
              ElevatedButton(
                onPressed: authProvider.isLoading ? null : _completeProfile,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authProvider.isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: LoadingIndicator(),
                      )
                    : Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              SizedBox(height: 20),
              
              // Skip for now (optional)
              TextButton(
                onPressed: authProvider.isLoading ? null : () {
                  // Navigate to home without completing profile
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

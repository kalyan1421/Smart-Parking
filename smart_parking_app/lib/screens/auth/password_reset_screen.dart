
// lib/screens/auth/password_reset_screen.dart - Password reset screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/core/utils/validators.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _resetSent = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(
      _emailController.text.trim()
    );
    
    if (success && mounted) {
      setState(() {
        _resetSent = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Icon(
                  Icons.lock_reset,
                  size: 70,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              
              // Success message
              if (_resetSent)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Password Reset Email Sent',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'We have sent password reset instructions to ${_emailController.text}. Please check your email inbox.',
                        style: TextStyle(color: Colors.green[800]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              
              // Error message
              if (!_resetSent && authProvider.error != null)
                Container(
                  padding: EdgeInsets.all(10),
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
              
              SizedBox(height: 20),
              
              // Reset instructions
              if (!_resetSent)
                Text(
                  'Enter your email address below, and we will send you instructions to reset your password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              
              SizedBox(height: 20),
              
              // Reset form
              if (!_resetSent)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: Validators.validateEmail,
                        onFieldSubmitted: (_) => _resetPassword(),
                      ),
                      
                      SizedBox(height: 30),
                      
                      // Reset button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _resetPassword,
                          child: authProvider.isLoading
                              ? LoadingIndicator(color: Colors.white)
                              : Text(
                                  'Send Reset Instructions',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Back to login button
              SizedBox(height: 20),
              if (_resetSent)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Back to Login',
                      style: TextStyle(fontSize: 16),
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
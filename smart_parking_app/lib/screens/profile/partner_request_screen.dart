// lib/screens/profile/partner_request_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/partner_request_service.dart';
import '../../models/partner_request.dart';
import '../../widgets/common/loading_indicator.dart';

class PartnerRequestScreen extends StatefulWidget {
  @override
  _PartnerRequestScreenState createState() => _PartnerRequestScreenState();
}

class _PartnerRequestScreenState extends State<PartnerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  PartnerRequest? _existingRequest;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingRequest();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        final request = await PartnerRequestService.getPartnerRequestByUserId(
          authProvider.currentUser!.id,
        );
        
        setState(() {
          _existingRequest = request;
          if (request != null) {
            _businessNameController.text = request.businessName ?? '';
            _businessAddressController.text = request.businessAddress ?? '';
            _phoneController.text = request.phoneNumber ?? '';
            _reasonController.text = request.reason ?? '';
          } else {
            // Pre-fill with user data
            _phoneController.text = authProvider.currentUser!.phoneNumber ?? '';
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading request: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        throw Exception('User not logged in');
      }

      final user = authProvider.currentUser!;

      // Check if already approved
      if (user.isPartnerApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already an approved QuickPark partner!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        return;
      }

      // Check if there's a pending request
      if (_existingRequest != null && 
          _existingRequest!.status == PartnerRequestStatus.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You already have a pending request. Please wait for admin approval.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await PartnerRequestService.submitPartnerRequest(
        userId: user.id,
        userEmail: user.email,
        userName: user.displayName,
        businessName: _businessNameController.text.trim().isEmpty 
            ? null 
            : _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim().isEmpty 
            ? null 
            : _businessAddressController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        reason: _reasonController.text.trim().isEmpty 
            ? null 
            : _reasonController.text.trim(),
      );

      // Refresh user data
      await authProvider.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partner request submitted successfully! Admin will review your request.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Become a QuickPark Partner'),
        ),
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }

    // Check if user is already approved
    if (authProvider.currentUser?.isPartnerApproved == true) {
      return Scaffold(
        appBar: AppBar(
          title: Text('QuickPark Partner'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                SizedBox(height: 24),
                Text(
                  'You are an approved QuickPark Partner!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'You can now add parking slots to the platform.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show request status if pending or rejected
    final requestStatus = _existingRequest?.status;
    final isPending = requestStatus == PartnerRequestStatus.pending;
    final isRejected = requestStatus == PartnerRequestStatus.rejected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Become a QuickPark Partner'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Partner Benefits',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('• Add and manage parking slots'),
                      Text('• Earn revenue from parking bookings'),
                      Text('• Reach more customers'),
                      Text('• Manage your parking business easily'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Status message
              if (isPending)
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Pending',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your request is being reviewed by admin. You will be notified once a decision is made.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isRejected)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Request Rejected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (_existingRequest?.adminNotes != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Admin Notes: ${_existingRequest!.adminNotes}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                        SizedBox(height: 8),
                        Text(
                          'You can submit a new request with updated information.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isPending) SizedBox(height: 24),

              // Error message
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form fields
              Text(
                'Business Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Business Name
              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business Name (Optional)',
                  hintText: 'Enter your business name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                enabled: !isPending,
              ),

              SizedBox(height: 16),

              // Business Address
              TextFormField(
                controller: _businessAddressController,
                decoration: InputDecoration(
                  labelText: 'Business Address (Optional)',
                  hintText: 'Enter your business address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                enabled: !isPending,
                maxLines: 2,
              ),

              SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Contact Phone Number',
                  hintText: 'Enter your phone number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                enabled: !isPending,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24),

              Text(
                'Why do you want to become a QuickPark Partner?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'Tell us why you want to become a partner...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                enabled: !isPending,
                maxLines: 4,
              ),

              SizedBox(height: 32),

              // Submit button
              if (!isPending)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    child: _isSubmitting
                        ? LoadingIndicator(color: Colors.white)
                        : Text(
                            'Submit Partner Request',
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

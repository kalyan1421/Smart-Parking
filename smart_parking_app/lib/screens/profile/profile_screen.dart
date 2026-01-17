// lib/screens/profile/profile_screen.dart - User profile with booking integration
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/screens/profile/booking_history_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  bool _isEditing = false;
  int _activeBookingsCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadBookingData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }
  
  void _initializeFields() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      _nameController.text = authProvider.currentUser!.displayName;
      _phoneController.text = authProvider.currentUser!.phoneNumber ?? '';
      _cityController.text = authProvider.currentUser!.city ?? '';
      _emergencyContactController.text = authProvider.currentUser!.emergencyContact ?? '';
    }
  }
  
  Future<void> _loadBookingData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await bookingProvider.loadActiveBookings(authProvider.currentUser!.id);
      setState(() {
        _activeBookingsCount = bookingProvider.activeBookings.length;
      });
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile(
      name: _nameController.text,
      phoneNumber: _phoneController.text,
      city: _cityController.text,
      emergencyContact: _emergencyContactController.text,
    );
    
    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirmed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }
  
  void _navigateToBookingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingHistoryScreen(),
      ),
    ).then((_) => _loadBookingData());
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    
    if (authProvider.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
        ),
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _updateProfile,
            )
          else
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookingData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        authProvider.currentUser!.displayName.isNotEmpty
                            ? authProvider.currentUser!.displayName[0].toUpperCase()
                            : authProvider.currentUser!.email[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      authProvider.currentUser!.email,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      authProvider.currentUser!.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Active bookings summary card
              if (_activeBookingsCount > 0)
                Card(
                  margin: EdgeInsets.only(bottom: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: InkWell(
                    onTap: _navigateToBookingHistory,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_car,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Bookings',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _activeBookingsCount == 1
                                      ? 'You have 1 active parking booking'
                                      : 'You have $_activeBookingsCount active parking bookings',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Profile form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Phone number field
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // City field
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      enabled: _isEditing,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Emergency Contact field
                    TextFormField(
                      controller: _emergencyContactController,
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.contact_phone),
                      ),
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSettingItem(
                    Icons.vpn_key,
                    'Change Password',
                    () {
                      // TODO: Navigate to change password screen
                    },
                  ),
                  _buildSettingItem(
                    Icons.history,
                    'Booking History',
                    _navigateToBookingHistory,
                    trailingWidget: _activeBookingsCount > 0 
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_activeBookingsCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
                  ),
                  _buildSettingItem(
                    Icons.directions_car,
                    'Manage Vehicles',
                    () {
                      Navigator.pushNamed(context, AppRoutes.manageVehicles);
                    },
                  ),
                  // Partner request option
                  if (authProvider.currentUser?.isPartnerApproved != true)
                    _buildSettingItem(
                      Icons.business,
                      'Become a QuickPark Partner',
                      () {
                        Navigator.pushNamed(context, AppRoutes.partnerRequest);
                      },
                      trailingWidget: authProvider.currentUser?.partnerRequestStatus == 'pending'
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                    ),
                  _buildSettingItem(
                    Icons.notifications,
                    'Notifications',
                    () {
                      // TODO: Navigate to notifications screen
                    },
                  ),
                  _buildSettingItem(
                    Icons.help,
                    'Help & Support',
                    () {
                      // TODO: Navigate to help screen
                    },
                  ),
                  Divider(),
                  _buildSettingItem(
                    Icons.logout,
                    'Logout',
                    _logout,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {Color? color, Widget? trailingWidget}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.grey[700]),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: color ?? Colors.black,
              ),
            ),
            Spacer(),
            if (trailingWidget != null) 
              trailingWidget
            else
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
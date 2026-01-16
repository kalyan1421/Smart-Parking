// lib/screens/profile/booking_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/screens/parking/id_generator.dart';
import 'package:smart_parking_app/screens/parking/parking_directions_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:smart_parking_app/services/pdf_manager.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/screens/parking/rate_parking_screen.dart';
import 'package:smart_parking_app/screens/parking/report_issue_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BookingHistoryScreen extends StatefulWidget {
  @override
  _BookingHistoryScreenState createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load bookings data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your bookings')),
      );
      return;
    }
    
    final userId = authProvider.currentUser!.id;
    
    // Load active bookings
    await bookingProvider.loadActiveBookings(userId);
    
    // Load booking history
    await bookingProvider.loadBookingHistory(userId);
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  Future<void> _refreshBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    await _loadBookings();
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookingCard(Booking booking) {
    final parkingSpot = ParkingSpot(
      id: booking.parkingSpotId,
      name: booking.parkingSpotName,
      description: 'Booked parking spot',
      address: '', // Not available from booking
      latitude: booking.latitude,
      longitude: booking.longitude,
      totalSpots: 0, // Not available from booking
      availableSpots: 0, // Not available from booking
      pricePerHour: booking.totalPrice / (booking.endTime.difference(booking.startTime).inHours == 0 ? 1 : booking.endTime.difference(booking.startTime).inHours),
      amenities: [], // Not available from booking
      operatingHours: {},
      vehicleTypes: ['car'],
      ownerId: '',
      geoPoint: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isVerified: true,
    );
    
    // Status color based on booking status
    Color statusColor;
    String statusText;
    
    if (booking.isActive) {
      statusColor = Colors.green;
      statusText = 'ACTIVE';
    } else if (booking.isCompleted) {
      statusColor = Colors.blue;
      statusText = 'COMPLETED';
    } else {
      statusColor = Colors.red;
      statusText = 'CANCELLED';
    }
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Show full booking details
          _showBookingDetails(booking, parkingSpot);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.parkingSpotName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          booking.dateText,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    booking.timeText,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.timelapse, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    booking.durationText,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppConfig.currencySymbol}${booking.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (booking.isActive)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParkingDirectionsScreen(
                              parkingSpot: parkingSpot,
                            ),
                          ),
                        );
                      },
                      child: Text('DIRECTIONS'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showBookingDetails(Booking booking, ParkingSpot parkingSpot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.parkingSpotName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Booking Details',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: booking.isActive 
                              ? Colors.green.withOpacity(0.1) 
                              : booking.isCompleted 
                                  ? Colors.blue.withOpacity(0.1) 
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          booking.isActive 
                              ? 'ACTIVE' 
                              : booking.isCompleted 
                                  ? 'COMPLETED' 
                                  : 'CANCELLED',
                          style: TextStyle(
                            color: booking.isActive 
                                ? Colors.green 
                                : booking.isCompleted 
                                    ? Colors.blue 
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  
                  // QR Code Section
                  if (booking.isActive || booking.isConfirmed) ...[
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Scan to Enter/Exit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: booking.qrCode ?? booking.id,
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            booking.qrCode ?? booking.id,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildDivider(),
                    SizedBox(height: 24),
                  ],

                  // Booking details
                  _buildDetailRow(
                    context,
                    'Booking ID',
                    booking.id,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    context,
                    'Date',
                    booking.dateText,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    context,
                    'Time',
                    booking.timeText,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    context,
                    'Duration',
                    booking.durationText,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    context,
                    'Total Amount',
                    '${AppConfig.currencySymbol}${booking.totalPrice.toStringAsFixed(2)}',
                    isHighlighted: true,
                  ),
                  SizedBox(height: 32),
                  
                  // Receipt button (always available)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _generateReceipt(booking),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('GENERATE RECEIPT'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  if (booking.isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ParkingDirectionsScreen(
                                    parkingSpot: parkingSpot,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.directions),
                            label: Text('DIRECTIONS'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _cancelBooking(booking),
                            icon: Icon(Icons.cancel),
                            label: Text('CANCEL'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              // primary: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportIssueScreen(booking: booking),
                            ),
                          );
                        },
                        icon: Icon(Icons.report_problem, color: Colors.red),
                        label: Text('Report Issue', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ] else if (booking.isCompleted) ...[
                    if (booking.feedback == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RateParkingScreen(booking: booking),
                              ),
                            ).then((value) {
                              if (value == true) {
                                _loadBookings(); // Refresh to show rating
                              }
                            });
                          },
                          icon: Icon(Icons.star),
                          label: Text('RATE PARKING'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'You rated this ${booking.feedback!['rating']} stars',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _generateReceipt(Booking booking) async {
    try {
      await PdfManager.generateBookingReceipt(
        context: context,
        booking: booking,
        transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
        paymentMethod: 'Digital Payment',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('YES'),
            style: TextButton.styleFrom(
              // primary: Colors.red,
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    // Close details sheet
    Navigator.pop(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
            SizedBox(width: 16),
            Text('Cancelling booking...'),
          ],
        ),
      ),
    );
    
    try {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      await bookingProvider.cancelBookingWithReceipt(
        context,
        booking.id,
        refundReason: 'Booking cancelled by user',
      );
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Assume success if no exception was thrown
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlighted ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    
    if (authProvider.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('My Bookings'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view your bookings',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login screen
                },
                child: Text('LOG IN'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'ACTIVE'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: !_isInitialized || bookingProvider.isLoading
          ? Center(child: LoadingIndicator())
          : RefreshIndicator(
              onRefresh: _refreshBookings,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active bookings tab
                  bookingProvider.activeBookings.isEmpty
                      ? _buildEmptyState('You have no active bookings')
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: bookingProvider.activeBookings.length,
                          itemBuilder: (context, index) {
                            return _buildBookingCard(bookingProvider.activeBookings[index]);
                          },
                        ),
                  
                  // Booking history tab
                  bookingProvider.bookingHistory.isEmpty
                      ? _buildEmptyState('Your booking history is empty')
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: bookingProvider.bookingHistory.length,
                          itemBuilder: (context, index) {
                            return _buildBookingCard(bookingProvider.bookingHistory[index]);
                          },
                        ),
                ],
              ),
            ),
    );
  }}
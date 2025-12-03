// lib/screens/booking/booking_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/screens/parking/parking_directions_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
// PDF/payment flow removed for Phase 1 stabilization

class BookingConfirmationScreen extends StatefulWidget {
  final ParkingSpot parkingSpot;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final String bookingId;

  const BookingConfirmationScreen({
    Key? key,
    required this.parkingSpot,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.bookingId,
  }) : super(key: key);

  @override
  _BookingConfirmationScreenState createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isSaving = false;
  Booking? _createdBooking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _saveBookingToDatabase();
  }

  Future<void> _saveBookingToDatabase() async {
    if (_isSaving || _createdBooking != null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        throw Exception('User not logged in');
      }

      final booking = await bookingProvider.createBooking(
        authProvider.currentUser!.id,
        widget.parkingSpot,
        widget.startTime,
        widget.endTime,
        widget.totalPrice,
      );

      if (booking == null) {
        throw Exception('Failed to create booking');
      }

      setState(() {
        _createdBooking = booking;
        _isSaving = false;
      });

      // Phase 1: Show simple cash payment dialog
      if (booking != null && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Booking Confirmed'),
              ],
            ),
            content: Text('Pay Cash at Gate and show your Booking ID.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes = widget.endTime.difference(widget.startTime).inMinutes;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Confirmation'),
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingIndicator(),
                  SizedBox(height: 16),
                  Text('Saving your booking...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Error saving booking',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(_error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveBookingToDatabase,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Success icon and message
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 48,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Booking Confirmed!',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your parking spot has been reserved',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Booking details card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                          widget.parkingSpot.name,
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          widget.parkingSpot.description,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'CONFIRMED',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              
                              // Booking details
                              _buildInfoRow(
                                context, 
                                'Booking ID', 
                                _createdBooking?.id ?? widget.bookingId,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                context, 
                                'Date', 
                                '${widget.startTime.day}/${widget.startTime.month}/${widget.startTime.year}',
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                context, 
                                'Time', 
                                '${widget.startTime.hour.toString().padLeft(2, '0')}:${widget.startTime.minute.toString().padLeft(2, '0')} - ${widget.endTime.hour.toString().padLeft(2, '0')}:${widget.endTime.minute.toString().padLeft(2, '0')}',
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                context, 
                                'Duration', 
                                hours > 0 
                                    ? '${hours}h ${minutes > 0 ? '${minutes}m' : ''}' 
                                    : '${minutes}m',
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                context, 
                                'Total Amount', 
                                '${AppConfig.currencySymbol}${widget.totalPrice.toStringAsFixed(2)}',
                                isHighlighted: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Navigate to directions screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ParkingDirectionsScreen(
                                      parkingSpot: widget.parkingSpot,
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
                              onPressed: () {
                                // Return to home screen
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                              icon: Icon(Icons.home),
                              label: Text('HOME'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isHighlighted = false}) {
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
}
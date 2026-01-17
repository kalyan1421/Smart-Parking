// lib/screens/parking/parking_spot_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/core/database/database_service.dart';
import 'package:smart_parking_app/models/parking_spot.dart' hide TimeOfDay;
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/wallet_provider.dart';
import 'package:smart_parking_app/screens/parking/booking_confirmation_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class ParkingSpotBottomSheet extends StatefulWidget {
  @override
  _ParkingSpotBottomSheetState createState() => _ParkingSpotBottomSheetState();
}

class _ParkingSpotBottomSheetState extends State<ParkingSpotBottomSheet> {
  DateTime _startTime = DateTime.now().add(Duration(minutes: 15));
  DateTime _endTime = DateTime.now().add(Duration(hours: 1, minutes: 15));
  bool _isBooking = false;
  bool _useWallet = false;

  Future<void> _launchMaps(double lat, double lon) async {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch maps')),
      );
    }
  }

  bool _isPeakTime() {
    final now = DateTime.now();
    // Simple peak time logic: 8 AM - 10 AM and 5 PM - 7 PM
    return (now.hour >= 8 && now.hour <= 10) || (now.hour >= 17 && now.hour <= 19);
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
    );
    
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
        
        if (isStartTime) {
          _startTime = selectedDateTime;
          // Make sure end time is at least 30 minutes after start time
          if (_endTime.difference(_startTime).inMinutes < 30) {
            _endTime = _startTime.add(Duration(minutes: 30));
          }
        } else {
          _endTime = selectedDateTime;
          // Make sure end time is after start time
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(Duration(minutes: 30));
          }
        }
      });
    }
  }

  double _calculateTotalPrice() {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final spot = parkingProvider.selectedParkingSpot;
    
    if (spot == null) return 0;
    
    // Calculate hours (partial hours count as full hours)
    final durationMinutes = _endTime.difference(_startTime).inMinutes;
    final durationHours = (durationMinutes / 60).ceil();
    
    return spot.pricePerHour * durationHours;
  }

  Future<void> _bookParkingSpot() async {
    setState(() {
      _isBooking = true;
    });
    
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final spot = parkingProvider.selectedParkingSpot;
    
    if (spot == null) {
      setState(() {
        _isBooking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No parking spot selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Get current user ID
    final userId = authProvider.user?.id;

    if (userId == null) {
      setState(() {
        _isBooking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to book parking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate total price
    final totalPrice = _calculateTotalPrice();

    // Check wallet balance if selected
    if (_useWallet) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      // Ensure wallet data is loaded
      if (walletProvider.balance == 0) {
         await walletProvider.loadWalletData(userId);
      }
      
      if (walletProvider.balance < totalPrice) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient wallet balance. Please add money.')),
        );
        return;
      }
    }

    // Create booking in database
    final booking = await bookingProvider.createBooking(
      userId,
      spot,
      _startTime,
      _endTime,
      totalPrice,
    );
    
    if (booking != null) {
      // Process wallet payment if selected
      if (_useWallet) {
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        await walletProvider.payForBooking(userId, totalPrice, booking.id);
      }
      
      setState(() {
        _isBooking = false;
      });
      
      // Success! Close bottom sheet
      Navigator.of(context).pop();
      
      // Navigate to confirmation screen with real booking ID
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            parkingSpot: spot,
            startTime: _startTime,
            endTime: _endTime,
            totalPrice: totalPrice,
            bookingId: booking.id, // Use actual booking ID from database
          ),
        ),
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? 'Failed to book parking spot'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parkingProvider = Provider.of<ParkingProvider>(context);
    final spot = parkingProvider.selectedParkingSpot;
    
    if (spot == null) {
      return Container(
        height: 200,
        child: Center(
          child: Text('No parking spot selected'),
        ),
      );
    }
    
    final totalPrice = _calculateTotalPrice();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: !spot.isVerified 
                      ? Colors.orange.shade100 
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  !spot.isVerified ? 'UNVERIFIED' : 'VERIFIED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: !spot.isVerified 
                        ? Colors.orange.shade800 
                        : Colors.green.shade800,
                  ),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: spot.availableSpots > 0 
                      ? Colors.green.shade100 
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  spot.availableSpots > 0 
                      ? '${spot.availableSpots} AVAILABLE' 
                      : 'FULL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: spot.availableSpots > 0 
                        ? Colors.green.shade800 
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            spot.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  spot.address.isNotEmpty ? spot.address : spot.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.directions, color: Colors.blue),
                onPressed: () => _launchMaps(spot.latitude, spot.longitude),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text(
                '${spot.rating.toStringAsFixed(1)} (${spot.reviewCount} reviews)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_isPeakTime()) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Peak Time - High Demand',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.attach_money, size: 16),
              SizedBox(width: 4),
              Text(
                '${AppConfig.currencySymbol}${spot.pricePerHour.toStringAsFixed(2)}/hr',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (spot.amenities.isNotEmpty) ...[
                SizedBox(width: 16),
                ...spot.amenities.take(2).map((amenity) => 
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      amenity,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (spot.amenities.length > 2) 
                  Text('+${spot.amenities.length - 2} more'),
              ],
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Select Parking Duration',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, true),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START TIME',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, false),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END TIME',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Price:'),
                Text(
                  '${AppConfig.currencySymbol}${totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Wallet Payment Option
          Consumer<WalletProvider>(
            builder: (context, walletProvider, _) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Pay with Wallet (Balance: ${AppConfig.currencySymbol}${walletProvider.balance.toStringAsFixed(2)})'),
                value: _useWallet,
                onChanged: (value) {
                  setState(() {
                    _useWallet = value ?? false;
                  });
                },
                secondary: Icon(Icons.account_balance_wallet, color: Colors.blue),
              );
            },
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: spot.availableSpots > 0 && !_isBooking
                  ? _bookParkingSpot
                  : null,
              child: _isBooking
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: LoadingIndicator(size: 24),
                    )
                  : Text('BOOK NOW'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
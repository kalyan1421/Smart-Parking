
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/booking.dart';
import '../../services/admin_service.dart';
import '../../models/user.dart';
import '../../models/parking_spot.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailsScreen({Key? key, required this.booking}) : super(key: key);

  @override
  _BookingDetailsScreenState createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  User? _user;
  ParkingSpot? _parkingSpot;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final user = await adminService.getUserById(widget.booking.userId);
    final parkingSpot = await adminService.getParkingSpotById(widget.booking.parkingSpotId);
    setState(() {
      _user = user;
      _parkingSpot = parkingSpot;
    });
  }

  void _processBooking() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final result = await adminService.processBooking(widget.booking.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Details', style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: 8),
            Text('Name: ${_user?.displayName ?? 'Loading...'}'),
            Text('Email: ${_user?.email ?? 'Loading...'}'),
            SizedBox(height: 16),
            Text('Parking Details', style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: 8),
            Text('Spot: ${_parkingSpot?.name ?? 'Loading...'}'),
            Text('Address: ${_parkingSpot?.address ?? 'Loading...'}'),
            SizedBox(height: 16),
            Text('Booking Status', style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: 8),
            Text(widget.booking.status.name),
            SizedBox(height: 32),
            if (widget.booking.status == BookingStatus.confirmed)
              ElevatedButton(
                onPressed: _processBooking,
                child: Text('Check-in'),
              ),
            if (widget.booking.status == BookingStatus.active)
              ElevatedButton(
                onPressed: _processBooking,
                child: Text('Check-out'),
              ),
          ],
        ),
      ),
    );
  }
}

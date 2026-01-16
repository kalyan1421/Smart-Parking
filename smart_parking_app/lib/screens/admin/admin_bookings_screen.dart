// lib/screens/admin/admin_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking_app/core/database/database_service.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:intl/intl.dart';

class AdminBookingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Bookings'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService.collection('bookings')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return Center(child: LoadingIndicator());

          final bookings = snapshot.data!.docs.map((doc) => Booking.fromFirestore(doc)).toList();

          if (bookings.isEmpty) return Center(child: Text('No bookings found'));

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(booking.parkingSpotName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: ${booking.userId}'), // Ideally resolve user name
                      Text(
                        '${DateFormat('MMM d, h:mm a').format(booking.startTime)} - ${DateFormat('h:mm a').format(booking.endTime)}',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Status: ${booking.status.name.toUpperCase()}',
                        style: TextStyle(
                          color: _getStatusColor(booking.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: booking.isActive || booking.isConfirmed
                      ? IconButton(
                          icon: Icon(Icons.qr_code),
                          onPressed: () {
                            // Show QR code logic or action
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.active:
        return Colors.blue;
      case BookingStatus.completed:
        return Colors.grey;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.expired:
        return Colors.orange;
      default:
        return Colors.black;
    }
  }
}

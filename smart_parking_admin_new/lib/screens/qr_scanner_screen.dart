
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/booking.dart';
import 'package:smart_parking_admin_new/screens/bookings/booking_details_screen.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isProcessing = false;

  void _handleQRCode(String code) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    final adminService = Provider.of<AdminService>(context, listen: false);
    try {
      final booking = await adminService.getBookingById(code);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailsScreen(booking: booking),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
                final a = capture.barcodes.first.rawValue;
                if (a != null) {
                  _handleQRCode(a);
                }
              },
      ),
    );
  }
}

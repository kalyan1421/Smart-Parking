// lib/screens/admin/admin_qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/config/app_config.dart';

class AdminQRScannerScreen extends StatefulWidget {
  @override
  _AdminQRScannerScreenState createState() => _AdminQRScannerScreenState();
}

class _AdminQRScannerScreenState extends State<AdminQRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
    });

    // Code format assumption: PARK-<BookingID> or just <BookingID>
    // In our id_generator.dart we use PARK-<random> or UUID
    // Let's assume the QR contains the booking ID directly or prefixed
    
    // In previous steps we generated QR with: booking.qrCode ?? booking.id
    // And id_generator uses 'PARK-'+hex. 
    // But actual Firestore IDs are UUIDs (from BookingProvider.createBooking).
    
    // Let's try to find the booking by ID (the code itself)
    // If scanning fails, we can add a manual entry option.
    
    try {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final booking = await bookingProvider.getBookingById(code);
      
      if (booking != null) {
        _showBookingActionDialog(booking);
      } else {
        _showErrorDialog('Booking not found for code: $code');
      }
    } catch (e) {
      _showErrorDialog('Error processing code: $e');
    }
  }

  void _showBookingActionDialog(Booking booking) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Divider(),
            _buildDetail('Spot', booking.parkingSpotName),
            _buildDetail('User', booking.userId), // Ideally fetch user name
            _buildDetail('Status', booking.status.name.toUpperCase()),
            _buildDetail('Time', booking.timeText),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close sheet
                      setState(() => _isProcessing = false);
                    },
                    child: Text('CANCEL'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processBookingAction(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getActionColor(booking),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_getActionText(booking)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(Booking booking) {
    if (booking.isConfirmed) return Colors.green;
    if (booking.isActive) return Colors.red;
    return Colors.grey;
  }

  String _getActionText(Booking booking) {
    if (booking.isConfirmed) return 'CHECK IN';
    if (booking.isActive) return 'CHECK OUT';
    return 'CLOSE';
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _processBookingAction(Booking booking) async {
    Navigator.pop(context); // Close sheet
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    bool success = false;
    String message = '';

    if (booking.isConfirmed) {
      success = await bookingProvider.checkIn(booking.id);
      message = success ? 'Checked In Successfully' : 'Check In Failed';
    } else if (booking.isActive) {
      success = await bookingProvider.checkOut(booking.id);
      message = success ? 'Checked Out Successfully' : 'Check Out Failed';
    } else {
      message = 'No action available for this status';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Icon(Icons.error, color: Colors.red),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.white);
                  case TorchState.unavailable:
                    return const Icon(Icons.no_flash, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                  default:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _handleBarcode,
      ),
    );
  }
}

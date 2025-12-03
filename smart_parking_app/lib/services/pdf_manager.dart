// lib/services/pdf_manager.dart - PDF management and operations
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import 'pdf_service.dart';

class PdfManager {
  /// Generate and handle booking receipt
  static Future<void> generateBookingReceipt({
    required BuildContext context,
    required Booking booking,
    String? transactionId,
    String? paymentMethod,
    bool autoSave = true,
    bool showShareDialog = true,
  }) async {
    try {
      // Get user and parking spot details
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      
      final user = authProvider.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Find the parking spot
      ParkingSpot? parkingSpot;
      try {
        parkingSpot = parkingProvider.parkingSpots
            .firstWhere((spot) => spot.id == booking.parkingSpotId);
      } catch (e) {
        // Create a minimal parking spot from booking data
        parkingSpot = ParkingSpot(
          id: booking.parkingSpotId,
          name: booking.parkingSpotName,
          description: 'Booked parking location',
          address: '', // Could be enhanced with reverse geocoding
          latitude: booking.latitude,
          longitude: booking.longitude,
          totalSpots: 1,
          availableSpots: 0,
          pricePerHour: booking.totalPrice / 
              (booking.endTime.difference(booking.startTime).inHours == 0 ? 1 : 
               booking.endTime.difference(booking.startTime).inHours),
          amenities: [],
          operatingHours: {},
          vehicleTypes: ['car'],
          ownerId: '',
          geoPoint: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isVerified: true,
        );
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating receipt...'),
            ],
          ),
        ),
      );

      // Generate PDF
      final pdfBytes = await PdfService.generateBookingReceipt(
        booking: booking,
        user: user,
        parkingSpot: parkingSpot,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      final fileName = 'parking_receipt_${booking.id}.pdf';

      if (autoSave) {
        // Save to device
        final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to: $filePath'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => PdfService.sharePdf(pdfBytes, fileName),
            ),
          ),
        );
      }

      if (showShareDialog) {
        // Show share options
        _showPdfActionDialog(context, pdfBytes, fileName);
      }
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Generate and handle payment receipt
  static Future<void> generatePaymentReceipt({
    required BuildContext context,
    required Booking booking,
    required String transactionId,
    required String paymentMethod,
    required double amountPaid,
    bool autoSave = true,
    bool showShareDialog = true,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating payment receipt...'),
            ],
          ),
        ),
      );

      // Generate PDF
      final pdfBytes = await PdfService.generatePaymentReceipt(
        booking: booking,
        user: user,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      final fileName = 'payment_receipt_${transactionId}.pdf';

      if (autoSave) {
        final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment receipt saved to: $filePath'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => PdfService.sharePdf(pdfBytes, fileName),
            ),
          ),
        );
      }

      if (showShareDialog) {
        _showPdfActionDialog(context, pdfBytes, fileName);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate payment receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Generate and handle refund receipt
  static Future<void> generateRefundReceipt({
    required BuildContext context,
    required Booking booking,
    required double refundAmount,
    required String refundReason,
    String? transactionId,
    bool autoSave = true,
    bool showShareDialog = true,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating refund receipt...'),
            ],
          ),
        ),
      );

      // Generate PDF
      final pdfBytes = await PdfService.generateRefundReceipt(
        booking: booking,
        user: user,
        refundAmount: refundAmount,
        refundReason: refundReason,
        transactionId: transactionId,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      final fileName = 'refund_receipt_${booking.id}.pdf';

      if (autoSave) {
        final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund receipt saved to: $filePath'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => PdfService.sharePdf(pdfBytes, fileName),
            ),
          ),
        );
      }

      if (showShareDialog) {
        _showPdfActionDialog(context, pdfBytes, fileName);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate refund receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show dialog with PDF action options
  static void _showPdfActionDialog(
    BuildContext context, 
    Uint8List pdfBytes, 
    String fileName
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Generated'),
        content: const Text('What would you like to do with your receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              PdfService.printPdf(pdfBytes);
            },
            child: const Text('Print'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              PdfService.sharePdf(pdfBytes, fileName);
            },
            child: const Text('Share'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Receipt saved to: $filePath'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Generate receipt automatically after successful booking
  static Future<void> handleBookingCompletion({
    required BuildContext context,
    required Booking booking,
    String? transactionId,
    String? paymentMethod,
  }) async {
    // Auto-generate receipt after successful booking
    await generateBookingReceipt(
      context: context,
      booking: booking,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
      autoSave: true,
      showShareDialog: false, // Don't show dialog automatically
    );

    // Show success message with option to view receipt
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Booking confirmed! Receipt generated.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Receipt',
          onPressed: () async {
            // Regenerate and show receipt
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
            
            final user = authProvider.currentUser;
            if (user == null) return;

            ParkingSpot? parkingSpot;
            try {
              parkingSpot = parkingProvider.parkingSpots
                  .firstWhere((spot) => spot.id == booking.parkingSpotId);
            } catch (e) {
              // Create minimal parking spot
              parkingSpot = ParkingSpot(
                id: booking.parkingSpotId,
                name: booking.parkingSpotName,
                description: 'Booked parking location',
                address: '',
                latitude: booking.latitude,
                longitude: booking.longitude,
                totalSpots: 1,
                availableSpots: 0,
                pricePerHour: booking.totalPrice,
                amenities: [],
                operatingHours: {},
                vehicleTypes: ['car'],
                ownerId: '',
                geoPoint: null,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isVerified: true,
              );
            }

            final pdfBytes = await PdfService.generateBookingReceipt(
              booking: booking,
              user: user,
              parkingSpot: parkingSpot,
              transactionId: transactionId,
              paymentMethod: paymentMethod,
            );

            _showPdfActionDialog(context, pdfBytes, 'parking_receipt_${booking.id}.pdf');
          },
        ),
      ),
    );
  }

  /// Generate receipt for booking cancellation/refund
  static Future<void> handleBookingCancellation({
    required BuildContext context,
    required Booking booking,
    required double refundAmount,
    String refundReason = 'Booking cancelled by user',
  }) async {
    if (refundAmount > 0) {
      await generateRefundReceipt(
        context: context,
        booking: booking,
        refundAmount: refundAmount,
        refundReason: refundReason,
        autoSave: true,
        showShareDialog: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking cancelled. Refund of \$${refundAmount.toStringAsFixed(2)} processed.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled. No refund applicable.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Batch generate receipts for multiple bookings
  static Future<void> generateBatchReceipts({
    required BuildContext context,
    required List<Booking> bookings,
  }) async {
    if (bookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bookings to generate receipts for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Generating ${bookings.length} receipts...'),
          ],
        ),
      ),
    );

    try {
      int successCount = 0;
      
      for (final booking in bookings) {
        try {
          await generateBookingReceipt(
            context: context,
            booking: booking,
            autoSave: true,
            showShareDialog: false,
          );
          successCount++;
        } catch (e) {
          // Continue with next booking if one fails
          print('Failed to generate receipt for booking ${booking.id}: $e');
        }
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $successCount of ${bookings.length} receipts'),
          backgroundColor: successCount == bookings.length ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate batch receipts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// lib/services/pdf_service.dart - PDF receipt generation service
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../config/app_config.dart';

class PdfService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: AppConfig.currencySymbol,
    decimalDigits: 2,
  );

  /// Generate a parking booking receipt PDF
  static Future<Uint8List> generateBookingReceipt({
    required Booking booking,
    required User user,
    required ParkingSpot parkingSpot,
    String? transactionId,
    String? paymentMethod,
  }) async {
    final pdf = pw.Document();

    // Calculate booking duration
    final duration = booking.endTime.difference(booking.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    // Calculate fees
    final subtotal = booking.totalPrice;
    final tax = subtotal * 0.18; // 18% GST
    final total = subtotal + tax;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Receipt Title
              pw.Center(
                child: pw.Text(
                  'PARKING RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Receipt Info
              _buildReceiptInfo(booking, transactionId),
              pw.SizedBox(height: 20),

              // Customer Details
              _buildCustomerDetails(user),
              pw.SizedBox(height: 20),

              // Parking Details
              _buildParkingDetails(parkingSpot, booking, hours, minutes),
              pw.SizedBox(height: 20),

              // Payment Summary
              _buildPaymentSummary(subtotal, tax, total, paymentMethod),
              pw.SizedBox(height: 30),

              // QR Code for booking
              if (booking.qrCode?.isNotEmpty == true)
                _buildQRCodeSection(booking.qrCode!),

              pw.Spacer(),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate a payment receipt PDF
  static Future<Uint8List> generatePaymentReceipt({
    required Booking booking,
    required User user,
    required String transactionId,
    required String paymentMethod,
    required double amountPaid,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Receipt Title
              pw.Center(
                child: pw.Text(
                  'PAYMENT RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Payment Info
              _buildPaymentInfo(transactionId, booking.id),
              pw.SizedBox(height: 20),

              // Customer Details
              _buildCustomerDetails(user),
              pw.SizedBox(height: 20),

              // Payment Details
              _buildPaymentDetails(booking, amountPaid, paymentMethod),
              pw.SizedBox(height: 30),

              pw.Spacer(),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate a refund receipt PDF
  static Future<Uint8List> generateRefundReceipt({
    required Booking booking,
    required User user,
    required double refundAmount,
    required String refundReason,
    String? transactionId,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Receipt Title
              pw.Center(
                child: pw.Text(
                  'REFUND RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Refund Info
              _buildRefundInfo(transactionId ?? 'N/A', booking.id),
              pw.SizedBox(height: 20),

              // Customer Details
              _buildCustomerDetails(user),
              pw.SizedBox(height: 20),

              // Refund Details
              _buildRefundDetails(booking, refundAmount, refundReason),
              pw.SizedBox(height: 30),

              pw.Spacer(),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper method to build header
  static pw.Widget _buildHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConfig.appName,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Smart Parking Solutions',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.blue600,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Date: ${_dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Version: ${AppConfig.appVersion}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build receipt info
  static pw.Widget _buildReceiptInfo(Booking booking, String? transactionId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Receipt #: ${booking.id}', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Booking ID: ${booking.id}'),
              if (transactionId != null) ...[
                pw.SizedBox(height: 5),
                pw.Text('Transaction ID: $transactionId'),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Status: ${booking.status.name.toUpperCase()}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Generated: ${_dateFormat.format(DateTime.now())}'),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build customer details
  static pw.Widget _buildCustomerDetails(User user) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CUSTOMER DETAILS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Name: ${user.displayName}'),
                    pw.SizedBox(height: 5),
                    pw.Text('Email: ${user.email}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (user.phoneNumber != null)
                      pw.Text('Phone: ${user.phoneNumber}'),
                    pw.SizedBox(height: 5),
                    pw.Text('User ID: ${user.id}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build parking details
  static pw.Widget _buildParkingDetails(
    ParkingSpot parkingSpot, 
    Booking booking, 
    int hours, 
    int minutes
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PARKING DETAILS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Location: ${parkingSpot.name}'),
                    pw.SizedBox(height: 5),
                    pw.Text('Address: ${parkingSpot.address}'),
                    pw.SizedBox(height: 5),
                    pw.Text('Check-in: ${_dateFormat.format(booking.startTime)}'),
                    pw.SizedBox(height: 5),
                    pw.Text('Check-out: ${_dateFormat.format(booking.endTime)}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Duration: ${hours}h ${minutes}m'),
                    pw.SizedBox(height: 5),
                    pw.Text('Rate: ${_currencyFormat.format(parkingSpot.pricePerHour)}/hr'),
                    pw.SizedBox(height: 5),
                    pw.Text('Vehicle ID: ${booking.vehicleId.isNotEmpty ? booking.vehicleId : 'Not specified'}'),
                    // Note: Vehicle details would need to be fetched separately using vehicleId
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build payment summary
  static pw.Widget _buildPaymentSummary(
    double subtotal, 
    double tax, 
    double total, 
    String? paymentMethod
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text('PAYMENT SUMMARY',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Subtotal:'),
              pw.Text(_currencyFormat.format(subtotal)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tax (18% GST):'),
              pw.Text(_currencyFormat.format(tax)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL:', 
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(_currencyFormat.format(total),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          if (paymentMethod != null) ...[
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Method:'),
                pw.Text(paymentMethod),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build QR code section
  static pw.Widget _buildQRCodeSection(String qrData) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text('Scan for Entry/Exit',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: 100,
            height: 100,
          ),
        ],
      ),
    );
  }

  // Helper method to build payment info
  static pw.Widget _buildPaymentInfo(String transactionId, String bookingId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Transaction ID: $transactionId',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Booking ID: $bookingId'),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Payment Date: ${_dateFormat.format(DateTime.now())}'),
              pw.SizedBox(height: 5),
              pw.Text('Status: PAID',
                style: pw.TextStyle(
                  color: PdfColors.green800,
                  fontWeight: pw.FontWeight.bold,
                )),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build payment details
  static pw.Widget _buildPaymentDetails(
    Booking booking, 
    double amountPaid, 
    String paymentMethod
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYMENT DETAILS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Amount Paid:'),
              pw.Text(_currencyFormat.format(amountPaid),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Payment Method:'),
              pw.Text(paymentMethod),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Booking Period:'),
              pw.Text('${_dateFormat.format(booking.startTime)} - ${_dateFormat.format(booking.endTime)}'),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build refund info
  static pw.Widget _buildRefundInfo(String transactionId, String bookingId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Refund ID: $transactionId',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Original Booking: $bookingId'),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Refund Date: ${_dateFormat.format(DateTime.now())}'),
              pw.SizedBox(height: 5),
              pw.Text('Status: PROCESSED',
                style: pw.TextStyle(
                  color: PdfColors.orange800,
                  fontWeight: pw.FontWeight.bold,
                )),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build refund details
  static pw.Widget _buildRefundDetails(
    Booking booking, 
    double refundAmount, 
    String refundReason
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('REFUND DETAILS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Original Amount:'),
              pw.Text(_currencyFormat.format(booking.totalPrice)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Refund Amount:'),
              pw.Text(_currencyFormat.format(refundAmount),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Reason: $refundReason'),
          pw.SizedBox(height: 5),
          pw.Text('Booking Period: ${_dateFormat.format(booking.startTime)} - ${_dateFormat.format(booking.endTime)}'),
        ],
      ),
    );
  }

  // Helper method to build footer
  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Thank you for using ${AppConfig.appName}!',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'For support, contact us at support@smartparking.com',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Terms and conditions apply. Visit our website for more details.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Save PDF to device storage
  static Future<String> savePdfToDevice(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Share PDF using system share dialog
  static Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  /// Print PDF using system print dialog
  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
  }
}

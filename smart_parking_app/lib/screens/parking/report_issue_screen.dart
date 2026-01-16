// lib/screens/parking/report_issue_screen.dart
import 'package:flutter/material.dart';
import 'package:smart_parking_app/models/booking.dart';

class ReportIssueScreen extends StatefulWidget {
  final Booking booking;

  const ReportIssueScreen({super.key, required this.booking});

  @override
  _ReportIssueScreenState createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final TextEditingController _detailsController = TextEditingController();
  String _selectedIssue = 'Other';
  bool _isSubmitting = false;

  final List<String> _issueTypes = [
    'Parking spot occupied',
    'Spot inaccessible',
    'Payment issue',
    'App not working',
    'Other',
  ];

  Future<void> _submitReport() async {
    if (_detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide some details')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate reporting
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report submitted. We will look into it.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Issue'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking ID: ${widget.booking.id}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Text(
              'What issue are you facing?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIssue,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _issueTypes.map((issue) {
                return DropdownMenuItem(
                  value: issue,
                  child: Text(issue),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedIssue = value!;
                });
              },
            ),
            SizedBox(height: 20),
            Text(
              'Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Please describe the issue...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('SUBMIT REPORT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

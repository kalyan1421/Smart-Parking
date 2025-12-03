// lib/screens/bookings/booking_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_provider.dart';
import '../../models/booking.dart';
import '../../config/theme.dart';
import '../../widgets/admin_drawer.dart';

class BookingManagementScreen extends StatefulWidget {
  const BookingManagementScreen({super.key});

  @override
  State<BookingManagementScreen> createState() => _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen> {
  BookingStatus? _statusFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadBookings(refresh: true);
      context.read<AdminProvider>().loadRevenueData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminProvider>().loadBookings(refresh: true);
              context.read<AdminProvider>().loadRevenueData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showRevenueAnalytics(),
          ),
        ],
      ),
      drawer: isDesktop ? null : const AdminDrawer(),
      body: Row(
        children: [
          if (isDesktop) const AdminDrawer(),
          Expanded(
            child: Column(
              children: [
                // Revenue Summary Card
                Consumer<AdminProvider>(
                  builder: (context, adminProvider, child) {
                    if (adminProvider.revenueData != null) {
                      return Container(
                        margin: const EdgeInsets.all(16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildRevenueStatTile(
                                    'Total Revenue',
                                    '\$${adminProvider.revenueData!.totalRevenue.toStringAsFixed(2)}',
                                    Icons.attach_money,
                                    AppTheme.successColor,
                                  ),
                                ),
                                const VerticalDivider(),
                                Expanded(
                                  child: _buildRevenueStatTile(
                                    'Total Bookings',
                                    adminProvider.revenueData!.totalBookings.toString(),
                                    Icons.book_online,
                                    AppTheme.primaryColor,
                                  ),
                                ),
                                const VerticalDivider(),
                                Expanded(
                                  child: _buildRevenueStatTile(
                                    'Average Booking Value',
                                    '\$${adminProvider.revenueData!.averageBookingValue.toStringAsFixed(2)}',
                                    Icons.trending_up,
                                    AppTheme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                // Filters
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search by user, parking spot, or booking ID...',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) {
                                    // Implement search functionality
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButton<BookingStatus?>(
                                  isExpanded: true,
                                  value: _statusFilter,
                                  hint: const Text('Filter by Status'),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Statuses'),
                                    ),
                                    ...BookingStatus.values.map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status.name.toUpperCase()),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _statusFilter = value;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectStartDate(),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      _startDate != null
                                          ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                          : 'Select start date',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectEndDate(),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date',
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      _endDate != null
                                          ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                          : 'Select end date',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _clearFilters,
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bookings List
                Expanded(
                  child: Consumer<AdminProvider>(
                    builder: (context, adminProvider, child) {
                      if (adminProvider.bookingsLoading && adminProvider.bookings.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (adminProvider.bookings.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_online,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No bookings found',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bookings will appear here as users make reservations',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: adminProvider.bookings.length + 
                                  (adminProvider.hasMoreBookings ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == adminProvider.bookings.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: adminProvider.bookingsLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () {
                                          adminProvider.loadBookings(
                                            statusFilter: _statusFilter,
                                            startDate: _startDate,
                                            endDate: _endDate,
                                          );
                                        },
                                        child: const Text('Load More'),
                                      ),
                              ),
                            );
                          }

                          final booking = adminProvider.bookings[index];
                          return _buildBookingCard(booking);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueStatTile(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Booking #${booking.id.substring(0, 8)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.getBookingStatusColor(booking.status.name)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.getBookingStatusColor(booking.status.name),
                              ),
                            ),
                            child: Text(
                              booking.status.name.toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.getBookingStatusColor(booking.status.name),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.parkingSpotName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'User ID: ${booking.userId.substring(0, 8)}...',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            booking.durationText,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${booking.totalPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                    Text(
                      '\$${booking.pricePerHour.toStringAsFixed(2)}/hr',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Date and Time Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(booking.startTime),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'End Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(booking.endTime),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Created',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(booking.createdAt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                if (booking.status == BookingStatus.pending)
                  OutlinedButton.icon(
                    onPressed: () => _updateBookingStatus(booking, BookingStatus.confirmed),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successColor,
                      side: BorderSide(color: AppTheme.successColor),
                    ),
                  ),
                if (booking.status == BookingStatus.confirmed)
                  OutlinedButton.icon(
                    onPressed: () => _updateBookingStatus(booking, BookingStatus.active),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                if (booking.status == BookingStatus.active)
                  OutlinedButton.icon(
                    onPressed: () => _updateBookingStatus(booking, BookingStatus.completed),
                    icon: const Icon(Icons.stop),
                    label: const Text('Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                      side: BorderSide(color: AppTheme.accentColor),
                    ),
                  ),
                if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _updateBookingStatus(booking, BookingStatus.cancelled),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleBookingMenuAction(value, booking),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_details',
                      child: ListTile(
                        leading: Icon(Icons.info),
                        title: Text('View Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_user',
                      child: ListTile(
                        leading: Icon(Icons.person),
                        title: Text('View User'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (booking.qrCode != null)
                      const PopupMenuItem(
                        value: 'view_qr',
                        child: ListTile(
                          leading: Icon(Icons.qr_code),
                          title: Text('View QR Code'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    context.read<AdminProvider>().loadBookings(
      refresh: true,
      statusFilter: _statusFilter,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
      _applyFilters();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
      _applyFilters();
    }
  }

  void _updateBookingStatus(Booking booking, BookingStatus newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Booking Status'),
        content: Text(
          'Change booking status from ${booking.status.name.toUpperCase()} to ${newStatus.name.toUpperCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminProvider>().updateBookingStatus(booking.id, newStatus);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _handleBookingMenuAction(String action, Booking booking) {
    switch (action) {
      case 'view_details':
        _showBookingDetails(booking);
        break;
      case 'view_user':
        // Navigate to user details
        break;
      case 'view_qr':
        _showQRCode(booking);
        break;
    }
  }

  void _showBookingDetails(Booking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Booking ID', booking.id),
              _buildDetailRow('User ID', booking.userId),
              _buildDetailRow('Parking Spot', booking.parkingSpotName),
              _buildDetailRow('Vehicle ID', booking.vehicleId),
              _buildDetailRow('Status', booking.status.name.toUpperCase()),
              _buildDetailRow('Total Price', '\$${booking.totalPrice.toStringAsFixed(2)}'),
              _buildDetailRow('Start Time', DateFormat('MMM dd, yyyy HH:mm').format(booking.startTime)),
              _buildDetailRow('End Time', DateFormat('MMM dd, yyyy HH:mm').format(booking.endTime)),
              if (booking.notes != null) _buildDetailRow('Notes', booking.notes!),
              if (booking.checkedInAt != null)
                _buildDetailRow('Checked In', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkedInAt!)),
              if (booking.checkedOutAt != null)
                _buildDetailRow('Checked Out', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkedOutAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showQRCode(Booking booking) {
    // Implement QR code display
  }

  void _showRevenueAnalytics() {
    // Navigate to detailed revenue analytics
  }
}

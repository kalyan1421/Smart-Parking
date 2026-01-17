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

class _BookingManagementScreenState extends State<BookingManagementScreen>
    with SingleTickerProviderStateMixin {
  BookingStatus? _statusFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = context.read<AdminProvider>();
      if (adminProvider.isRealTimeEnabled) {
        adminProvider.startBookingsRealTime();
      } else {
        adminProvider.loadBookings(refresh: true);
      }
      adminProvider.loadRevenueData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      drawer: isDesktop ? null : const AdminDrawer(),
      body: Row(
        children: [
          if (isDesktop) const AdminDrawer(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildRevenueHeader(isDark),
                  _buildFilterSection(isDark),
                  Expanded(
                    child: _buildBookingsList(isDark, isDesktop),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: Row(
        children: [
          if (isDark) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.neonOrange.withOpacity(0.3),
                    AppTheme.neonPurple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.book_online_rounded,
                color: AppTheme.neonOrange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            'Booking Management',
            style: TextStyle(
              color: isDark ? AppTheme.neonOrange : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Consumer<AdminProvider>(
          builder: (context, provider, _) => IconButton(
            icon: Icon(
              provider.isRealTimeEnabled ? Icons.sync : Icons.sync_disabled,
              color: provider.isRealTimeEnabled 
                  ? AppTheme.neonGreen 
                  : Colors.grey,
            ),
            onPressed: () {
              provider.toggleRealTimeMode(!provider.isRealTimeEnabled);
              if (provider.isRealTimeEnabled) {
                provider.startBookingsRealTime(statusFilter: _statusFilter);
              }
            },
            tooltip: provider.isRealTimeEnabled 
                ? 'Real-time enabled' 
                : 'Real-time disabled',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            final provider = context.read<AdminProvider>();
            if (provider.isRealTimeEnabled) {
              provider.startBookingsRealTime(statusFilter: _statusFilter);
            } else {
              provider.loadBookings(
                refresh: true,
                statusFilter: _statusFilter,
                startDate: _startDate,
                endDate: _endDate,
              );
            }
            provider.loadRevenueData();
          },
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
        ),
      ],
    );
  }

  Widget _buildRevenueHeader(bool isDark) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final revenue = adminProvider.revenueData;
        if (revenue == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      AppTheme.neonOrange.withOpacity(0.15),
                      AppTheme.neonPurple.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      AppTheme.warningColor.withOpacity(0.1),
                      AppTheme.accentColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.neonOrange.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRevenueStat(
                  'Total Revenue',
                  '₹${revenue.totalRevenue.toStringAsFixed(0)}',
                  Icons.currency_rupee_rounded,
                  isDark ? AppTheme.neonGreen : AppTheme.successColor,
                  isDark,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildRevenueStat(
                  'Total Bookings',
                  revenue.totalBookings.toString(),
                  Icons.book_online_rounded,
                  isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                  isDark,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildRevenueStat(
                  'Avg. Booking Value',
                  '₹${revenue.averageBookingValue.toStringAsFixed(0)}',
                  Icons.trending_up_rounded,
                  isDark ? AppTheme.neonPurple : AppTheme.accentColor,
                  isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueStat(String title, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(bool isDark) {
    if (!_showFilters) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by booking ID, user, or parking spot...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? AppTheme.neonOrange : null,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<AdminProvider>().searchBookings('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    context.read<AdminProvider>().searchBookings(value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildStatusDropdown(isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDatePicker('Start Date', _startDate, true, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker('End Date', _endDate, false, isDark)),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.neonPink : AppTheme.errorColor,
                  side: BorderSide(
                    color: (isDark ? AppTheme.neonPink : AppTheme.errorColor).withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BookingStatus?>(
          value: _statusFilter,
          hint: Text(
            'All Status',
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppTheme.neonOrange : null,
          ),
          dropdownColor: isDark ? const Color(0xFF21262D) : null,
          items: [
            DropdownMenuItem<BookingStatus?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 18, color: isDark ? const Color(0xFF8B949E) : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('All Status'),
                ],
              ),
            ),
            ...BookingStatus.values.map(
              (status) => DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.getBookingStatusColor(status.name),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.name.toUpperCase()),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _statusFilter = value);
            context.read<AdminProvider>().setBookingStatusFilter(value);
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, bool isStart, bool isDark) {
    return InkWell(
      onTap: () => _selectDate(isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: isDark ? AppTheme.neonOrange : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(bool isDark, bool isDesktop) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.bookingsLoading && adminProvider.bookings.isEmpty) {
          return _buildLoadingState(isDark);
        }

        final bookings = adminProvider.bookings;

        if (bookings.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length + (adminProvider.hasMoreBookings ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == bookings.length) {
              return _buildLoadMoreButton(adminProvider, isDark);
            }

            final booking = bookings[index];
            return _buildBookingCard(booking, isDark, index);
          },
        );
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                isDark ? AppTheme.neonOrange : AppTheme.warningColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading bookings...',
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.neonOrange : AppTheme.warningColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_online_rounded,
              size: 64,
              color: isDark ? AppTheme.neonOrange : AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No bookings found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookings will appear here as users make reservations',
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(AdminProvider adminProvider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: adminProvider.bookingsLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                  isDark ? AppTheme.neonOrange : AppTheme.warningColor,
                ),
              )
            : OutlinedButton.icon(
                onPressed: () => adminProvider.loadBookings(
                  statusFilter: _statusFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load More'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.neonOrange : null,
                  side: BorderSide(
                    color: isDark ? AppTheme.neonOrange : AppTheme.primaryColor,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark, int index) {
    final statusColor = AppTheme.getBookingStatusColor(booking.status.name);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 300)),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? statusColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBookingDetails(booking, isDark),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookingHeader(booking, statusColor, isDark),
                  const SizedBox(height: 16),
                  _buildBookingInfo(booking, isDark),
                  const SizedBox(height: 16),
                  _buildBookingTimeline(booking, isDark),
                  if (_showActionButtons(booking)) ...[
                    const SizedBox(height: 16),
                    _buildActionButtons(booking, isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingHeader(Booking booking, Color statusColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.neonBlue : AppTheme.primaryColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking.id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                booking.parkingSpotName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            booking.status.name.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingInfo(Booking booking, bool isDark) {
    return Row(
      children: [
        _buildInfoChip(
          Icons.person_outline_rounded,
          'User: ${booking.userId.substring(0, 8)}...',
          isDark,
        ),
        const SizedBox(width: 12),
        _buildInfoChip(
          Icons.currency_rupee_rounded,
          '₹${booking.totalPrice.toStringAsFixed(0)}',
          isDark,
        ),
        const SizedBox(width: 12),
        _buildInfoChip(
          Icons.timer_outlined,
          booking.durationText,
          isDark,
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF8B949E) : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTimeline(Booking booking, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildTimePoint(
            'Start',
            DateFormat('MMM dd').format(booking.startTime),
            DateFormat('HH:mm').format(booking.startTime),
            isDark ? AppTheme.neonGreen : AppTheme.successColor,
            isDark,
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppTheme.neonGreen : AppTheme.successColor,
                    isDark ? AppTheme.neonOrange : AppTheme.warningColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          _buildTimePoint(
            'End',
            DateFormat('MMM dd').format(booking.endTime),
            DateFormat('HH:mm').format(booking.endTime),
            isDark ? AppTheme.neonOrange : AppTheme.warningColor,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePoint(String label, String date, String time, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : null,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool _showActionButtons(Booking booking) {
    return booking.status == BookingStatus.pending ||
           booking.status == BookingStatus.confirmed ||
           booking.status == BookingStatus.active;
  }

  Widget _buildActionButtons(Booking booking, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (booking.status == BookingStatus.pending)
          _buildActionButton(
            'Confirm',
            Icons.check_rounded,
            isDark ? AppTheme.neonGreen : AppTheme.successColor,
            () => _updateBookingStatus(booking, BookingStatus.confirmed, isDark),
            isDark,
          ),
        if (booking.status == BookingStatus.confirmed)
          _buildActionButton(
            'Start',
            Icons.play_arrow_rounded,
            isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
            () => _updateBookingStatus(booking, BookingStatus.active, isDark),
            isDark,
          ),
        if (booking.status == BookingStatus.active)
          _buildActionButton(
            'Complete',
            Icons.stop_rounded,
            isDark ? AppTheme.neonPurple : AppTheme.accentColor,
            () => _updateBookingStatus(booking, BookingStatus.completed, isDark),
            isDark,
          ),
        if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed)
          _buildActionButton(
            'Cancel',
            Icons.cancel_rounded,
            isDark ? AppTheme.neonPink : AppTheme.errorColor,
            () => _updateBookingStatus(booking, BookingStatus.cancelled, isDark),
            isDark,
            isOutlined: true,
          ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isDark, {
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  void _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final provider = context.read<AdminProvider>();
    if (provider.isRealTimeEnabled) {
      provider.startBookingsRealTime(statusFilter: _statusFilter);
    } else {
      provider.loadBookings(
        refresh: true,
        statusFilter: _statusFilter,
        startDate: _startDate,
        endDate: _endDate,
      );
    }
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

  void _updateBookingStatus(Booking booking, BookingStatus newStatus, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Booking Status',
          style: TextStyle(color: isDark ? Colors.white : null),
        ),
        content: Text(
          'Change booking status from ${booking.status.name.toUpperCase()} to ${newStatus.name.toUpperCase()}?',
          style: TextStyle(color: isDark ? const Color(0xFF8B949E) : null),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getBookingStatusColor(newStatus.name),
              foregroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(Booking booking, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Booking ID', booking.id, isDark),
              _buildDetailRow('User ID', booking.userId, isDark),
              _buildDetailRow('Parking Spot', booking.parkingSpotName, isDark),
              _buildDetailRow('Vehicle ID', booking.vehicleId, isDark),
              _buildDetailRow('Status', booking.status.name.toUpperCase(), isDark),
              _buildDetailRow('Total Price', '₹${booking.totalPrice.toStringAsFixed(2)}', isDark),
              _buildDetailRow('Start Time', DateFormat('MMM dd, yyyy HH:mm').format(booking.startTime), isDark),
              _buildDetailRow('End Time', DateFormat('MMM dd, yyyy HH:mm').format(booking.endTime), isDark),
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _buildDetailRow('Notes', booking.notes!, isDark),
              if (booking.checkedInAt != null)
                _buildDetailRow('Checked In', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkedInAt!), isDark),
              if (booking.checkedOutAt != null)
                _buildDetailRow('Checked Out', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkedOutAt!), isDark),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8B949E) : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/screens/parking/parking_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../providers/admin_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/theme.dart';
import '../../widgets/admin_drawer.dart';
import 'add_parking_spot_screen.dart';
import 'edit_parking_spot_dialog.dart';

class ParkingManagementScreen extends StatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  State<ParkingManagementScreen> createState() => _ParkingManagementScreenState();
}

class _ParkingManagementScreenState extends State<ParkingManagementScreen>
    with SingleTickerProviderStateMixin {
  ParkingSpotStatus? _statusFilter;
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
        adminProvider.startParkingSpotsRealTime();
      } else {
        adminProvider.loadParkingSpots(refresh: true);
      }
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
      floatingActionButton: _buildFAB(isDark),
      body: Row(
        children: [
          if (isDesktop) const AdminDrawer(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildStatsBar(isDark),
                  _buildSearchAndFilter(isDark),
                  Expanded(
                    child: _buildParkingSpotsList(isDark),
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
                    AppTheme.neonGreen.withOpacity(0.3),
                    AppTheme.neonBlue.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: AppTheme.neonGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            'Parking Management',
            style: TextStyle(
              color: isDark ? AppTheme.neonGreen : null,
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
                provider.startParkingSpotsRealTime(statusFilter: _statusFilter);
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
              provider.startParkingSpotsRealTime(statusFilter: _statusFilter);
            } else {
              provider.loadParkingSpots(refresh: true, statusFilter: _statusFilter);
            }
          },
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _showAddParkingSpotDialog(),
          tooltip: 'Add Parking Spot',
        ),
      ],
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: FloatingActionButton.extended(
        onPressed: () => _showAddParkingSpotDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Spot'),
        backgroundColor: isDark ? AppTheme.neonGreen : null,
        foregroundColor: isDark ? const Color(0xFF0D1117) : null,
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final spots = adminProvider.parkingSpots;
        final totalSpots = spots.length;
        final availableCount = spots.where((s) => s.status == ParkingSpotStatus.available).length;
        final occupiedCount = spots.where((s) => s.status == ParkingSpotStatus.occupied).length;
        final maintenanceCount = spots.where((s) => s.status == ParkingSpotStatus.maintenance).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              _buildMiniStat('Total', totalSpots.toString(), Icons.local_parking_rounded,
                  isDark ? AppTheme.neonBlue : AppTheme.primaryColor, isDark),
              const SizedBox(width: 16),
              _buildMiniStat('Available', availableCount.toString(), Icons.check_circle_rounded,
                  isDark ? AppTheme.neonGreen : AppTheme.successColor, isDark),
              const SizedBox(width: 16),
              _buildMiniStat('Occupied', occupiedCount.toString(), Icons.remove_circle_rounded,
                  isDark ? AppTheme.neonOrange : AppTheme.warningColor, isDark),
              const SizedBox(width: 16),
              _buildMiniStat('Maintenance', maintenanceCount.toString(), Icons.build_circle_rounded,
                  isDark ? AppTheme.neonPink : AppTheme.errorColor, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppTheme.neonBlue.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search parking spots...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppTheme.neonBlue : null,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<AdminProvider>().searchParkingSpots('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF21262D) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  context.read<AdminProvider>().searchParkingSpots(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Status filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ParkingSpotStatus?>(
                value: _statusFilter,
                hint: Text(
                  'All Status',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                  ),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppTheme.neonBlue : null,
                ),
                dropdownColor: isDark ? const Color(0xFF21262D) : null,
                items: [
                  DropdownMenuItem<ParkingSpotStatus?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.all_inclusive, size: 18, color: isDark ? const Color(0xFF8B949E) : Colors.grey),
                        const SizedBox(width: 8),
                        const Text('All Status'),
                      ],
                    ),
                  ),
                  ...ParkingSpotStatus.values.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppTheme.getParkingSpotStatusColor(status.name),
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
                  setState(() {
                    _statusFilter = value;
                  });
                  context.read<AdminProvider>().setParkingSpotStatusFilter(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingSpotsList(bool isDark) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.parkingSpotsLoading && adminProvider.parkingSpots.isEmpty) {
          return _buildLoadingState(isDark);
        }

        final spots = adminProvider.parkingSpots;

        if (spots.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: spots.length + (adminProvider.hasMoreParkingSpots ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == spots.length) {
              return _buildLoadMoreButton(adminProvider, isDark);
            }

            final parkingSpot = spots[index];
            return _buildParkingSpotCard(parkingSpot, isDark, index);
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
                isDark ? AppTheme.neonGreen : AppTheme.successColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading parking spots...',
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
              color: (isDark ? AppTheme.neonGreen : AppTheme.successColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_parking_rounded,
              size: 64,
              color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No parking spots found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first parking spot to get started',
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddParkingSpotDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Parking Spot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.neonGreen : null,
              foregroundColor: isDark ? const Color(0xFF0D1117) : null,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
        child: adminProvider.parkingSpotsLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                  isDark ? AppTheme.neonGreen : AppTheme.successColor,
                ),
              )
            : OutlinedButton.icon(
                onPressed: () {
                  adminProvider.loadParkingSpots(statusFilter: _statusFilter);
                },
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load More'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.neonGreen : null,
                  side: BorderSide(
                    color: isDark ? AppTheme.neonGreen : AppTheme.primaryColor,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildParkingSpotCard(ParkingSpot parkingSpot, bool isDark, int index) {
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
            color: isDark
                ? AppTheme.getParkingSpotStatusColor(parkingSpot.status.name).withOpacity(0.3)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: AppTheme.getParkingSpotStatusColor(parkingSpot.status.name).withOpacity(0.1),
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
            onTap: () => _showEditParkingSpotDialog(parkingSpot),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(parkingSpot, isDark),
                  const SizedBox(height: 12),
                  _buildCardAddress(parkingSpot, isDark),
                  if (parkingSpot.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      parkingSpot.description,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildCardStats(parkingSpot, isDark),
                  const SizedBox(height: 16),
                  _buildCardActions(parkingSpot, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(ParkingSpot parkingSpot, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.neonBlue : AppTheme.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  parkingSpot.id,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parkingSpot.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildStatusBadge(parkingSpot.status, isDark),
        if (parkingSpot.isVerified) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.neonGreen : AppTheme.successColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_rounded,
              color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(ParkingSpotStatus status, bool isDark) {
    final color = AppTheme.getParkingSpotStatusColor(status.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardAddress(ParkingSpot parkingSpot, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parkingSpot.address,
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCardStats(ParkingSpot parkingSpot, bool isDark) {
    return Row(
      children: [
        _buildStatChip(
          Icons.local_parking_rounded,
          '${parkingSpot.availableSpots}/${parkingSpot.totalSpots}',
          'Slots',
          isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
          isDark,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          Icons.currency_rupee_rounded,
          '₹${parkingSpot.pricePerHour.toStringAsFixed(0)}/hr',
          'Price',
          isDark ? AppTheme.neonGreen : AppTheme.successColor,
          isDark,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          Icons.star_rounded,
          parkingSpot.rating.toStringAsFixed(1),
          'Rating',
          isDark ? AppTheme.neonOrange : AppTheme.warningColor,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardActions(ParkingSpot parkingSpot, bool isDark) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => _showEditParkingSpotDialog(parkingSpot),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
            side: BorderSide(
              color: (isDark ? AppTheme.neonBlue : AppTheme.primaryColor).withOpacity(0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _toggleVerification(parkingSpot),
          icon: Icon(
            parkingSpot.isVerified ? Icons.verified_rounded : Icons.verified_outlined,
            size: 18,
          ),
          label: Text(parkingSpot.isVerified ? 'Verified' : 'Verify'),
          style: OutlinedButton.styleFrom(
            foregroundColor: parkingSpot.isVerified
                ? (isDark ? AppTheme.neonGreen : AppTheme.successColor)
                : (isDark ? AppTheme.neonOrange : AppTheme.warningColor),
            side: BorderSide(
              color: (parkingSpot.isVerified
                      ? (isDark ? AppTheme.neonGreen : AppTheme.successColor)
                      : (isDark ? AppTheme.neonOrange : AppTheme.warningColor))
                  .withOpacity(0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, parkingSpot),
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_bookings',
              child: ListTile(
                leading: Icon(Icons.book_online_rounded),
                title: Text('View Bookings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_revenue',
              child: ListTile(
                leading: Icon(Icons.analytics_rounded),
                title: Text('View Revenue'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_rounded, color: isDark ? AppTheme.neonPink : Colors.red),
                title: Text('Delete', style: TextStyle(color: isDark ? AppTheme.neonPink : Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddParkingSpotDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddParkingSpotScreen(),
      ),
    );

    if (result == true && mounted) {
      // Real-time stream will auto-update
    }
  }

  void _showEditParkingSpotDialog(ParkingSpot parkingSpot) {
    showDialog(
      context: context,
      builder: (context) => EditParkingSpotDialog(parkingSpot: parkingSpot),
    );
  }

  void _toggleVerification(ParkingSpot parkingSpot) {
    context.read<AdminProvider>().verifyParkingSpot(
      parkingSpot.id,
      !parkingSpot.isVerified,
    );
  }

  void _handleMenuAction(String action, ParkingSpot parkingSpot) {
    switch (action) {
      case 'view_bookings':
        // Navigate to bookings filtered by this parking spot
        break;
      case 'view_revenue':
        // Navigate to revenue analytics for this parking spot
        break;
      case 'delete':
        _showDeleteConfirmation(parkingSpot);
        break;
    }
  }

  void _showDeleteConfirmation(ParkingSpot parkingSpot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Parking Spot',
          style: TextStyle(color: isDark ? Colors.white : null),
        ),
        content: Text(
          'Are you sure you want to delete "${parkingSpot.name}"? This action cannot be undone.',
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
              context.read<AdminProvider>().deleteParkingSpot(parkingSpot.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.neonPink : Colors.red,
              foregroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

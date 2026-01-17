// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/admin_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAdminStats();
      context.read<AdminProvider>().loadRevenueData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminProvider>().loadAdminStats();
              context.read<AdminProvider>().loadRevenueData();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  // Navigate to profile
                  break;
                case 'settings':
                  // Navigate to settings
                  break;
                case 'logout':
                  context.read<AuthProvider>().signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return CircleAvatar(
                    backgroundImage: authProvider.currentUser?.photoURL != null
                        ? NetworkImage(authProvider.currentUser!.photoURL!)
                        : null,
                    child: authProvider.currentUser?.photoURL == null
                        ? Text(
                            authProvider.currentUser?.displayName.isNotEmpty == true
                                ? authProvider.currentUser!.displayName[0].toUpperCase()
                                : 'A',
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      drawer: isDesktop ? null : const AdminDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.qrScanner);
        },
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: Row(
        children: [
          if (isDesktop) const AdminDrawer(),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, adminProvider, child) {
                if (adminProvider.statsLoading && adminProvider.adminStats == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor.withOpacity(0.8),
                                    AppTheme.primaryColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: authProvider.currentUser?.photoURL != null
                                          ? NetworkImage(authProvider.currentUser!.photoURL!)
                                          : null,
                                      child: authProvider.currentUser?.photoURL == null
                                          ? Text(
                                              authProvider.currentUser?.displayName.isNotEmpty == true
                                                  ? authProvider.currentUser!.displayName[0].toUpperCase()
                                                  : 'A',
                                              style: const TextStyle(fontSize: 24, color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome back, ${authProvider.currentUser?.displayName ?? 'Admin'}!',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Here\'s what\'s happening with your parking system today.',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Colors.white.withOpacity(0.9),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Statistics Cards
                      if (adminProvider.adminStats != null) ...[
                        ResponsiveRowColumn(
                          layout: isDesktop 
                              ? ResponsiveRowColumnType.ROW 
                              : ResponsiveRowColumnType.COLUMN,
                          children: [
                            ResponsiveRowColumnItem(
                              rowFlex: 1,
                              child: StatCard(
                                title: 'Total Users',
                                value: adminProvider.adminStats!.totalUsers.toString(),
                                icon: Icons.group_add,
                                color: AppTheme.primaryColor,
                                trend: '+5% vs last week',
                                onTap: () => Navigator.pushNamed(context, AppRoutes.userManagement),
                              ),
                            ),
                            ResponsiveRowColumnItem(
                              rowFlex: 1,
                              child: StatCard(
                                title: 'Parking Spots',
                                value: adminProvider.adminStats!.totalParkingSpots.toString(),
                                icon: Icons.local_parking,
                                color: AppTheme.successColor,
                                trend: '+2% vs last week',
                                onTap: () => Navigator.pushNamed(context, AppRoutes.parkingManagement),
                              ),
                            ),
                            ResponsiveRowColumnItem(
                              rowFlex: 1,
                              child: StatCard(
                                title: 'Total Bookings',
                                value: adminProvider.adminStats!.totalBookings.toString(),
                                icon: Icons.book_online,
                                color: AppTheme.warningColor,
                                trend: '+10% vs last week',
                                onTap: () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                              ),
                            ),
                            ResponsiveRowColumnItem(
                              rowFlex: 1,
                              child: StatCard(
                                title: 'Total Revenue',
                                value: '₹${adminProvider.adminStats!.totalRevenue.toStringAsFixed(2)}',
                                icon: Icons.monetization_on,
                                color: AppTheme.accentColor,
                                trend: '+8% vs last week',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Charts Section
                        ResponsiveRowColumn(
                          layout: isDesktop 
                              ? ResponsiveRowColumnType.ROW 
                              : ResponsiveRowColumnType.COLUMN,
                          children: [
                            ResponsiveRowColumnItem(
                              rowFlex: 2,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Weekly Revenue',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 200,
                                        child: LineChart(
                                          LineChartData(
                                            gridData: FlGridData(show: false),
                                            titlesData: FlTitlesData(show: false),
                                            borderData: FlBorderData(show: false),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: [
                                                  FlSpot(0, 3),
                                                  FlSpot(1, 1),
                                                  FlSpot(2, 4),
                                                  FlSpot(3, 2),
                                                  FlSpot(4, 5),
                                                  FlSpot(5, 3),
                                                  FlSpot(6, 4),
                                                ],
                                                isCurved: true,
                                                color: AppTheme.primaryColor,
                                                barWidth: 4,
                                                isStrokeCapRound: true,
                                                dotData: FlDotData(show: false),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ResponsiveRowColumnItem(
                              rowFlex: 1,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Booking Status',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: _buildPieChartSections(
                                              adminProvider.adminStats!.bookingsByStatus,
                                            ),
                                            centerSpaceRadius: 40,
                                            sectionsSpace: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Quick Access Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.dashboard, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Quick Access',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Quick Access Buttons
                                if (isDesktop) ...[
                                  Row(
                                    children: [
                                      Expanded(child: _buildQuickAccessCard(
                                        context,
                                        'All Users',
                                        'View and manage all registered users',
                                        Icons.people,
                                        Colors.blue,
                                        () => Navigator.pushNamed(context, AppRoutes.userManagement),
                                      )),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildQuickAccessCard(
                                        context,
                                        'All Parking Spots',
                                        'View and manage all parking locations',
                                        Icons.local_parking,
                                        Colors.green,
                                        () => Navigator.pushNamed(context, AppRoutes.parkingManagement),
                                      )),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildQuickAccessCard(
                                        context,
                                        'All Bookings',
                                        'View and manage all parking orders',
                                        Icons.book_online,
                                        Colors.orange,
                                        () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                                      )),
                                    ],
                                  ),
                                ] else ...[
                                  _buildQuickAccessCard(
                                    context,
                                    'All Users',
                                    'View and manage all registered users',
                                    Icons.people,
                                    Colors.blue,
                                    () => Navigator.pushNamed(context, AppRoutes.userManagement),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildQuickAccessCard(
                                    context,
                                    'All Parking Spots',
                                    'View and manage all parking locations',
                                    Icons.local_parking,
                                    Colors.green,
                                    () => Navigator.pushNamed(context, AppRoutes.parkingManagement),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildQuickAccessCard(
                                    context,
                                    'All Bookings',
                                    'View and manage all parking orders',
                                    Icons.book_online,
                                    Colors.orange,
                                    () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Recent Activity
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Activity',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Add recent activity list here
                                const Center(
                                  child: Text('Recent bookings and activities will appear here'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      // Error handling
                      if (adminProvider.error != null)
                        Card(
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    adminProvider.error!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => adminProvider.clearError(),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> data) {
    final colors = [
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.primaryColor,
      AppTheme.accentColor,
    ];

    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildQuickStat(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

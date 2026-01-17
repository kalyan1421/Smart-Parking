// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = context.read<AdminProvider>();
      adminProvider.loadRevenueData();
      // Real-time stats are loaded automatically via stream
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
              child: Consumer<AdminProvider>(
                builder: (context, adminProvider, child) {
                  if (adminProvider.statsLoading && adminProvider.adminStats == null) {
                    return _buildLoadingState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () => adminProvider.refreshAll(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(isDark, isDesktop),
                          const SizedBox(height: 24),
                          _buildLiveIndicator(adminProvider, isDark),
                          const SizedBox(height: 16),
                          _buildStatsGrid(adminProvider, isDesktop, isDark),
                          const SizedBox(height: 24),
                          _buildChartsSection(adminProvider, isDesktop, isDark),
                          const SizedBox(height: 24),
                          _buildQuickAccessSection(isDesktop, isDark),
                          const SizedBox(height: 24),
                          _buildRecentActivitySection(adminProvider, isDark),
                          if (adminProvider.error != null)
                            _buildErrorCard(adminProvider, isDark),
                        ],
                      ),
                    ),
                  );
                },
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
                    AppTheme.neonBlue.withOpacity(0.3),
                    AppTheme.neonPurple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: AppTheme.neonBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            'Dashboard',
            style: TextStyle(
              color: isDark ? AppTheme.neonBlue : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
        actions: [
        // Real-time toggle
        Consumer<AdminProvider>(
          builder: (context, provider, _) => IconButton(
            icon: Icon(
              provider.isRealTimeEnabled ? Icons.sync : Icons.sync_disabled,
              color: provider.isRealTimeEnabled 
                  ? AppTheme.neonGreen 
                  : Colors.grey,
            ),
            onPressed: () => provider.toggleRealTimeMode(!provider.isRealTimeEnabled),
            tooltip: provider.isRealTimeEnabled 
                ? 'Real-time enabled' 
                : 'Real-time disabled',
          ),
        ),
          IconButton(
          icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
            context.read<AdminProvider>().refreshAll();
          },
          tooltip: 'Refresh',
        ),
        _buildProfileMenu(isDark),
      ],
    );
  }

  Widget _buildProfileMenu(bool isDark) {
    return PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  break;
                case 'settings':
                  break;
                case 'logout':
                  context.read<AuthProvider>().signOut();
                  break;
              }
            },
      offset: const Offset(0, 50),
            itemBuilder: (context) => [
        PopupMenuItem(
                value: 'profile',
                child: ListTile(
            leading: Icon(Icons.person_outline, color: isDark ? AppTheme.neonBlue : null),
            title: const Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
        PopupMenuItem(
                value: 'settings',
                child: ListTile(
            leading: Icon(Icons.settings_outlined, color: isDark ? AppTheme.neonPurple : null),
            title: const Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
        PopupMenuItem(
                value: 'logout',
                child: ListTile(
            leading: Icon(Icons.logout, color: isDark ? AppTheme.neonPink : Colors.red),
            title: Text('Sign Out', style: TextStyle(color: isDark ? AppTheme.neonPink : Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
            return Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark ? AppTheme.darkNeonGradient : null,
                border: isDark
                    ? Border.all(color: AppTheme.neonBlue.withOpacity(0.5), width: 2)
                    : null,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? const Color(0xFF21262D) : null,
                    backgroundImage: authProvider.currentUser?.photoURL != null
                        ? NetworkImage(authProvider.currentUser!.photoURL!)
                        : null,
                    child: authProvider.currentUser?.photoURL == null
                        ? Text(
                            authProvider.currentUser?.displayName.isNotEmpty == true
                                ? authProvider.currentUser!.displayName[0].toUpperCase()
                                : 'A',
                        style: TextStyle(
                          color: isDark ? AppTheme.neonBlue : null,
                          fontWeight: FontWeight.bold,
                        ),
                          )
                        : null,
              ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonBlue.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.qrScanner);
        },
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading dashboard...',
            style: TextStyle(
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isDark, bool isDesktop) {
    return Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
        final greeting = _getGreeting();
        final name = authProvider.currentUser?.displayName ?? 'Admin';
        
        return Container(
          padding: EdgeInsets.all(isDesktop ? 28 : 20),
                              decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                                  colors: [
                      AppTheme.neonBlue.withOpacity(0.15),
                      AppTheme.neonPurple.withOpacity(0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                  )
                : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(
                    color: AppTheme.neonBlue.withOpacity(0.3),
                    width: 1,
                  )
                : null,
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppTheme.neonBlue.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
                                child: Row(
                                  children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDark ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.waving_hand_rounded,
                  color: isDark ? AppTheme.neonOrange : Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                      '$greeting, $name!',
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                                          Text(
                      _getDateString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark 
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white.withOpacity(0.9),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
        );
      },
    );
  }

  Widget _buildLiveIndicator(AdminProvider adminProvider, bool isDark) {
    if (!adminProvider.isRealTimeEnabled) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.neonGreen.withOpacity(0.1)
            : AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.neonGreen.withOpacity(0.3)
              : AppTheme.successColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: isDark ? AppTheme.neonGreen : AppTheme.successColor),
          const SizedBox(width: 10),
          Text(
            'Real-time updates active',
            style: TextStyle(
              color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (adminProvider.adminStats != null) ...[
            const SizedBox(width: 16),
            Text(
              'Last updated: ${DateFormat('HH:mm:ss').format(adminProvider.adminStats!.lastUpdated)}',
              style: TextStyle(
                color: isDark 
                    ? const Color(0xFF8B949E)
                    : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AdminProvider adminProvider, bool isDesktop, bool isDark) {
    final stats = adminProvider.adminStats;
    if (stats == null) return const SizedBox.shrink();

    final cards = [
      StatCard(
                                title: 'Total Users',
        value: stats.totalUsers.toString(),
        icon: Icons.group_rounded,
        color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
        isLive: adminProvider.isRealTimeEnabled,
        animationDelay: 0,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.userManagement),
                              ),
      StatCard(
                                title: 'Parking Spots',
        value: stats.totalParkingSpots.toString(),
        icon: Icons.local_parking_rounded,
        color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
        trend: '+${stats.availableParkingSpots} available',
        animationDelay: 100,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.parkingManagement),
                              ),
      StatCard(
        title: 'Active Bookings',
        value: stats.activeBookings.toString(),
        icon: Icons.book_online_rounded,
        color: isDark ? AppTheme.neonOrange : AppTheme.warningColor,
        isLive: adminProvider.isRealTimeEnabled,
        animationDelay: 200,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                              ),
      StatCard(
                                title: 'Total Revenue',
        value: '₹${stats.totalRevenue.toStringAsFixed(0)}',
        icon: Icons.currency_rupee_rounded,
        color: isDark ? AppTheme.neonPurple : AppTheme.accentColor,
        trend: '₹${stats.todayRevenue.toStringAsFixed(0)} today',
        animationDelay: 300,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((card) => Expanded(child: card)).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            Expanded(child: cards[1]),
          ],
        ),
        Row(
          children: [
            Expanded(child: cards[2]),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection(AdminProvider adminProvider, bool isDesktop, bool isDark) {
    final stats = adminProvider.adminStats;
    if (stats == null) return const SizedBox.shrink();

    return ResponsiveRowColumn(
      layout: isDesktop ? ResponsiveRowColumnType.ROW : ResponsiveRowColumnType.COLUMN,
      rowSpacing: 16,
      columnSpacing: 16,
                          children: [
                            ResponsiveRowColumnItem(
                              rowFlex: 2,
          child: _buildRevenueChart(adminProvider, isDark),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildBookingStatusChart(stats, isDark),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(AdminProvider adminProvider, bool isDark) {
    return GlassCard(
      glowColor: isDark ? AppTheme.neonBlue : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                'Revenue Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.neonBlue.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
                                      SizedBox(
            height: 220,
                                        child: LineChart(
                                          LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFE2E8F0),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                              fontSize: 11,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                                            borderData: FlBorderData(show: false),
                                            lineBarsData: [
                                              LineChartBarData(
                    spots: const [
                                                  FlSpot(0, 3),
                                                  FlSpot(1, 1),
                                                  FlSpot(2, 4),
                                                  FlSpot(3, 2),
                                                  FlSpot(4, 5),
                                                  FlSpot(5, 3),
                                                  FlSpot(6, 4),
                                                ],
                                                isCurved: true,
                    curveSmoothness: 0.35,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                    barWidth: 3,
                                                isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                          strokeWidth: 2,
                          strokeColor: isDark ? const Color(0xFF21262D) : Colors.white,
                        );
                      },
                    ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                      gradient: LinearGradient(
                        colors: [
                          (isDark ? AppTheme.neonBlue : AppTheme.primaryColor).withOpacity(0.3),
                          (isDark ? AppTheme.neonBlue : AppTheme.primaryColor).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
    );
  }

  Widget _buildBookingStatusChart(dynamic stats, bool isDark) {
    return GlassCard(
      glowColor: isDark ? AppTheme.neonPurple : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Booking Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 24),
                                      SizedBox(
            height: 180,
                                        child: PieChart(
                                          PieChartData(
                sections: _buildPieChartSections(stats.bookingsByStatus, isDark),
                centerSpaceRadius: 45,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(stats.bookingsByStatus, isDark),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> data, bool isDark) {
    final colors = isDark
        ? [AppTheme.neonGreen, AppTheme.neonOrange, AppTheme.neonPink, AppTheme.neonBlue, AppTheme.neonPurple]
        : [AppTheme.successColor, AppTheme.warningColor, AppTheme.errorColor, AppTheme.primaryColor, AppTheme.accentColor];

    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: entry.value.toString(),
        color: color,
        radius: 28,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF0D1117) : Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> data, bool isDark) {
    final colors = isDark
        ? [AppTheme.neonGreen, AppTheme.neonOrange, AppTheme.neonPink, AppTheme.neonBlue, AppTheme.neonPurple]
        : [AppTheme.successColor, AppTheme.warningColor, AppTheme.errorColor, AppTheme.primaryColor, AppTheme.accentColor];

    int index = 0;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.entries.map((entry) {
        final color = colors[index % colors.length];
        index++;
    return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.key,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuickAccessSection(bool isDesktop, bool isDark) {
    final actions = [
      _QuickAction(
        title: 'Users',
        subtitle: 'Manage all users',
        icon: Icons.people_rounded,
        color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
        route: AppRoutes.userManagement,
      ),
      _QuickAction(
        title: 'Parking',
        subtitle: 'Manage locations',
        icon: Icons.local_parking_rounded,
        color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
        route: AppRoutes.parkingManagement,
      ),
      _QuickAction(
        title: 'Bookings',
        subtitle: 'View all orders',
        icon: Icons.book_online_rounded,
        color: isDark ? AppTheme.neonOrange : AppTheme.warningColor,
        route: AppRoutes.bookingManagement,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : null,
          ),
        ),
        const SizedBox(height: 16),
        if (isDesktop)
          Row(
            children: actions
                .map((action) => Expanded(child: _buildQuickAccessCard(action, isDark)))
                .toList(),
          )
        else
          Column(
            children: actions
                .map((action) => _buildQuickAccessCard(action, isDark))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildQuickAccessCard(_QuickAction action, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, action.route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? action.color.withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: action.color.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, color: action.color, size: 26),
                ),
                const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 2),
              Text(
                        action.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF8B949E)
                              : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF8B949E) : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(AdminProvider adminProvider, bool isDark) {
    return GlassCard(
      glowColor: isDark ? AppTheme.neonCyan : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingManagement),
                child: Text(
                  'View All',
                style: TextStyle(
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Placeholder for recent activity
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: isDark ? const Color(0xFF8B949E) : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recent bookings and activities will appear here',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(AdminProvider adminProvider, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.neonPink : AppTheme.errorColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppTheme.neonPink : AppTheme.errorColor).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: isDark ? AppTheme.neonPink : AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              adminProvider.error!,
              style: TextStyle(color: isDark ? AppTheme.neonPink : AppTheme.errorColor),
            ),
          ),
          TextButton(
            onPressed: () => adminProvider.clearError(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getDateString() {
    final now = DateTime.now();
    return DateFormat('EEEE, MMMM d, yyyy').format(now);
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5 * _controller.value),
                blurRadius: 8 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

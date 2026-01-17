// lib/widgets/admin_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../config/app_config.dart';
import '../config/routes.dart';
import '../config/theme.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: isDesktop ? 280 : null,
      child: Drawer(
        backgroundColor: isDark ? const Color(0xFF161B22) : null,
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),

            // Real-time indicator
            _buildRealTimeIndicator(context, isDark),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionTitle('Main', isDark),
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    route: AppRoutes.dashboard,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.local_parking_rounded,
                    title: 'Parking Spots',
                    route: AppRoutes.parkingManagement,
                    color: isDark ? AppTheme.neonGreen : AppTheme.successColor,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.book_online_rounded,
                    title: 'Bookings',
                    route: AppRoutes.bookingManagement,
                    color: isDark ? AppTheme.neonOrange : AppTheme.warningColor,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_rounded,
                    title: 'Users',
                    route: AppRoutes.userManagement,
                    color: isDark ? AppTheme.neonPurple : AppTheme.accentColor,
                    isDark: isDark,
                  ),
                  
                  _buildDivider(isDark),
                  _buildSectionTitle('Tools', isDark),
                  
                  _buildDrawerItem(
                    context,
                    icon: Icons.map_rounded,
                    title: 'Map View',
                    route: AppRoutes.parkingMapView,
                    color: isDark ? AppTheme.neonCyan : Colors.teal,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'QR Scanner',
                    route: AppRoutes.qrScanner,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                    isDark: isDark,
                  ),
                  
                  _buildDivider(isDark),
                  _buildSectionTitle('Settings', isDark),
                  
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_rounded,
                    title: 'Analytics',
                    color: isDark ? AppTheme.neonPink : Colors.pink,
                    isDark: isDark,
                    onTap: () {
                      // Navigate to analytics
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    color: isDark ? const Color(0xFF8B949E) : Colors.grey,
                    isDark: isDark,
                    onTap: () {
                      // Navigate to settings
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    color: isDark ? const Color(0xFF8B949E) : Colors.grey,
                    isDark: isDark,
                    onTap: () {
                      // Navigate to help
                    },
                  ),
                ],
              ),
            ),

            // Footer
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.neonBlue.withOpacity(0.15),
                  AppTheme.neonPurple.withOpacity(0.15),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.accentColor,
                ],
              ),
        border: isDark
            ? Border(
                bottom: BorderSide(
                  color: AppTheme.neonBlue.withOpacity(0.3),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            AppTheme.neonBlue.withOpacity(0.5),
                            AppTheme.neonPurple.withOpacity(0.5),
                          ],
                        )
                      : null,
                  border: isDark
                      ? Border.all(
                          color: AppTheme.neonBlue.withOpacity(0.5),
                          width: 2,
                        )
                      : null,
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: isDark
                      ? const Color(0xFF21262D)
                      : Colors.white.withOpacity(0.2),
                  backgroundImage: authProvider.currentUser?.photoURL != null
                      ? NetworkImage(authProvider.currentUser!.photoURL!)
                      : null,
                  child: authProvider.currentUser?.photoURL == null
                      ? Text(
                          authProvider.currentUser?.displayName.isNotEmpty == true
                              ? authProvider.currentUser!.displayName[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontSize: 24,
                            color: isDark ? AppTheme.neonBlue : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.currentUser?.displayName ?? 'Admin',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authProvider.currentUser?.email ?? '',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF8B949E)
                            : Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.neonPink : Colors.white)
                            .withOpacity(isDark ? 0.2 : 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? AppTheme.neonPink : Colors.white)
                              .withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        authProvider.isAdmin ? 'ADMIN' : 'OPERATOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.neonPink : Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRealTimeIndicator(BuildContext context, bool isDark) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: adminProvider.isRealTimeEnabled
                      ? (isDark ? AppTheme.neonGreen : AppTheme.successColor)
                      : Colors.grey,
                  boxShadow: adminProvider.isRealTimeEnabled
                      ? [
                          BoxShadow(
                            color: (isDark ? AppTheme.neonGreen : AppTheme.successColor)
                                .withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  adminProvider.isRealTimeEnabled
                      ? 'Real-time sync active'
                      : 'Real-time sync disabled',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                  ),
                ),
              ),
              Switch(
                value: adminProvider.isRealTimeEnabled,
                onChanged: (value) => adminProvider.toggleRealTimeMode(value),
                activeColor: isDark ? AppTheme.neonGreen : AppTheme.successColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF8B949E) : Colors.grey[500],
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Divider(
        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        height: 1,
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    String? route,
    VoidCallback? onTap,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(isDark ? 0.15 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected && isDark
            ? Border.all(color: color.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDark ? 0.2 : 0.15)
                : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? color : (isDark ? const Color(0xFF8B949E) : Colors.grey[600]),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.white : color)
                : (isDark ? const Color(0xFFC9D1D9) : Colors.grey[800]),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap ??
            (route != null
                ? () {
                    if (currentRoute != route) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        route,
                        (route) => false,
                      );
                    }
                  }
                : null),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<AuthProvider>().signOut();
              },
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: isDark ? AppTheme.neonPink : Colors.red,
              ),
              label: Text(
                'Sign Out',
                style: TextStyle(
                  color: isDark ? AppTheme.neonPink : Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: (isDark ? AppTheme.neonPink : Colors.red).withOpacity(0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Quickpark Admin v${AppConfig.version}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

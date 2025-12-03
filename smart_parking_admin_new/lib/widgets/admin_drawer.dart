// lib/widgets/admin_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../config/routes.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    return SizedBox(
      width: isDesktop ? 280 : null,
      child: Drawer(
        child: Column(
          children: [
            // Header
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(AppConfig.colors['primary']),
                    Color(AppConfig.colors['primaryDark']),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: authProvider.currentUser?.photoURL != null
                                ? NetworkImage(authProvider.currentUser!.photoURL!)
                                : null,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: authProvider.currentUser?.photoURL == null
                                ? Text(
                                    authProvider.currentUser?.displayName.isNotEmpty == true
                                        ? authProvider.currentUser!.displayName[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            authProvider.currentUser?.displayName ?? 'Admin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authProvider.currentUser?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    route: AppRoutes.dashboard,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.local_parking,
                    title: 'Parking Management',
                    route: AppRoutes.parkingManagement,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.map,
                    title: 'Parking Map View',
                    route: AppRoutes.parkingMapView,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.book_online,
                    title: 'Booking Management',
                    route: AppRoutes.bookingManagement,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people,
                    title: 'User Management',
                    route: AppRoutes.userManagement,
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics,
                    title: 'Analytics',
                    onTap: () {
                      // Navigate to analytics
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Navigate to settings
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    context,
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      // Navigate to help
                    },
                  ),
                ],
              ),
            ),
            
            // Footer
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<AuthProvider>().signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Version
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Version ${AppConfig.version}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? route,
    VoidCallback? onTap,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Color(AppConfig.colors['primary']) : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Color(AppConfig.colors['primary']) : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Color(AppConfig.colors['primary']).withOpacity(0.1),
      onTap: onTap ?? (route != null ? () {
        if (currentRoute != route) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            route,
            (route) => false,
          );
        }
      } : null),
    );
  }
}

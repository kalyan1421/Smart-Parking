// lib/screens/parking/filter_bar.dart
// Modern filter bar with glassmorphism and smooth animations

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';

class ParkingFilterBar extends StatelessWidget {
  final bool showLabels;
  final EdgeInsets padding;
  
  const ParkingFilterBar({
    super.key,
    this.showLabels = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Consumer<ParkingProvider>(
        builder: (context, provider, _) {
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Sort By
              _FilterChip(
                label: _getSortLabel(provider.sortBy),
                icon: Icons.sort,
                isActive: provider.sortBy != 'distance',
                onTap: () => _showSortOptions(context, provider),
              ),
              const SizedBox(width: 8),
              
              // Price Range
              _FilterChip(
                label: _getPriceLabel(provider.minPrice, provider.maxPrice),
                icon: Icons.attach_money,
                isActive: provider.minPrice > 0 || provider.maxPrice < 500,
                onTap: () => _showPriceFilter(context, provider),
              ),
              const SizedBox(width: 8),
              
              // Distance - default is 10km now
              _FilterChip(
                label: '${(provider.searchRadius / 1000).toStringAsFixed(1)} km',
                icon: Icons.radar,
                isActive: provider.searchRadius != 10000, // Changed to 10km default
                onTap: () => _showDistanceFilter(context, provider),
              ),
              const SizedBox(width: 8),
              
              // Amenities
              _FilterChip(
                label: provider.selectedAmenities.isEmpty 
                    ? 'Amenities' 
                    : '${provider.selectedAmenities.length} selected',
                icon: Icons.local_parking,
                isActive: provider.selectedAmenities.isNotEmpty,
                onTap: () => _showAmenitiesFilter(context, provider),
              ),
              const SizedBox(width: 8),
              
              // Vehicle Type
              _FilterChip(
                label: provider.selectedVehicleTypes.isEmpty 
                    ? 'Vehicle' 
                    : provider.selectedVehicleTypes.first,
                icon: Icons.directions_car,
                isActive: provider.selectedVehicleTypes.isNotEmpty,
                onTap: () => _showVehicleTypeFilter(context, provider),
              ),
              const SizedBox(width: 8),
              
              // Available Only Toggle
              _ToggleChip(
                label: 'Available',
                icon: Icons.check_circle,
                isActive: provider.showAvailableOnly,
                onToggle: (value) => provider.setShowAvailableOnly(value),
              ),
              
              // Clear all button if any filter is active
              if (_hasActiveFilters(provider)) ...[
                const SizedBox(width: 8),
                _ClearFiltersChip(
                  onTap: () {
                    provider.clearFilters();
                    // Show snackbar to confirm
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Filters reset'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(width: 16),
            ],
          );
        },
      ),
    );
  }

  bool _hasActiveFilters(ParkingProvider provider) {
    return provider.sortBy != 'distance' ||
           provider.minPrice > 0 ||
           provider.maxPrice < 500 ||
           provider.searchRadius != 10000 || // Changed to 10km default
           provider.selectedAmenities.isNotEmpty ||
           provider.selectedVehicleTypes.isNotEmpty ||
           !provider.showAvailableOnly;
  }
  
  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'price':
        return 'By Price';
      case 'rating':
        return 'By Rating';
      case 'availability':
        return 'By Spots';
      default:
        return 'Nearby';
    }
  }
  
  String _getPriceLabel(double min, double max) {
    if (min == 0 && max >= 500) return 'Any Price';
    if (min == 0) return '< ₹${max.toInt()}';
    if (max >= 500) return '> ₹${min.toInt()}';
    return '₹${min.toInt()}-${max.toInt()}';
  }
  
  void _showSortOptions(BuildContext context, ParkingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SortBottomSheet(provider: provider),
    );
  }
  
  void _showPriceFilter(BuildContext context, ParkingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PriceFilterSheet(provider: provider),
    );
  }
  
  void _showDistanceFilter(BuildContext context, ParkingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DistanceFilterSheet(provider: provider),
    );
  }
  
  void _showAmenitiesFilter(BuildContext context, ParkingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AmenitiesFilterSheet(provider: provider),
    );
  }
  
  void _showVehicleTypeFilter(BuildContext context, ParkingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleTypeFilterSheet(provider: provider),
    );
  }
}

// Custom filter chip with modern design
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? theme.primaryColor.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.primaryColor : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? theme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? theme.primaryColor : Colors.grey.shade700,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? theme.primaryColor : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}

// Toggle chip for boolean filters
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onToggle,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => onToggle(!isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF4CAF50).withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isActive ? const Color(0xFF4CAF50) : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Clear filters chip
class _ClearFiltersChip extends StatelessWidget {
  final VoidCallback onTap;
  
  const _ClearFiltersChip({required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sort options bottom sheet
class _SortBottomSheet extends StatelessWidget {
  final ParkingProvider provider;
  
  const _SortBottomSheet({required this.provider});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sort, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Sort By',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSortOption(context, 'distance', 'Distance', 'Nearest first', Icons.near_me),
                _buildSortOption(context, 'price', 'Price', 'Lowest first', Icons.attach_money),
                _buildSortOption(context, 'rating', 'Rating', 'Highest first', Icons.star),
                _buildSortOption(context, 'availability', 'Availability', 'Most spots first', Icons.local_parking),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildSortOption(BuildContext context, String value, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = provider.sortBy == value;
    
    return GestureDetector(
      onTap: () {
        provider.updateSortBy(value);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.primaryColor : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? theme.primaryColor : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.primaryColor),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Price filter bottom sheet - NOW WITH APPLY BUTTON
class _PriceFilterSheet extends StatefulWidget {
  final ParkingProvider provider;
  
  const _PriceFilterSheet({required this.provider});
  
  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  late RangeValues _values;
  
  @override
  void initState() {
    super.initState();
    _values = RangeValues(widget.provider.minPrice, widget.provider.maxPrice);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_money, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Price Range',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Per hour parking rate',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                
                // Price display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceBox('Min', _values.start),
                    Container(
                      width: 30,
                      height: 2,
                      color: Colors.grey.shade300,
                    ),
                    _buildPriceBox('Max', _values.end),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Range slider - Only updates local state, NOT provider
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: theme.primaryColor,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: theme.primaryColor,
                    overlayColor: theme.primaryColor.withOpacity(0.2),
                    rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
                    rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                  ),
                  child: RangeSlider(
                    values: _values,
                    min: 0,
                    max: 500,
                    divisions: 50,
                    onChanged: (values) {
                      setState(() {
                        _values = values;
                      });
                      // DON'T update provider here - wait for Apply
                    },
                  ),
                ),
                
                // Quick options - Also only update local state
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickOption('Any', 0, 500),
                    _buildQuickOption('< ₹50', 0, 50),
                    _buildQuickOption('₹50-100', 50, 100),
                    _buildQuickOption('₹100-200', 100, 200),
                    _buildQuickOption('> ₹200', 200, 500),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.provider.updatePriceRange(_values.start, _values.end);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Price Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildPriceBox(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${value.toInt()}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickOption(String label, double min, double max) {
    final isSelected = _values.start == min && _values.end == max;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _values = RangeValues(min, max);
        });
        // DON'T update provider here - wait for Apply
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primaryColor : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Distance filter bottom sheet - NOW WITH APPLY BUTTON
class _DistanceFilterSheet extends StatefulWidget {
  final ParkingProvider provider;
  
  const _DistanceFilterSheet({required this.provider});
  
  @override
  State<_DistanceFilterSheet> createState() => _DistanceFilterSheetState();
}

class _DistanceFilterSheetState extends State<_DistanceFilterSheet> {
  late double _radius;
  
  @override
  void initState() {
    super.initState();
    _radius = widget.provider.searchRadius;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Search Radius',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Find parking within this distance',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                
                // Radius display
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withOpacity(0.1),
                      border: Border.all(
                        color: theme.primaryColor,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (_radius / 1000).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          Text(
                            'km',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Slider - Only updates local state
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: theme.primaryColor,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: theme.primaryColor,
                    overlayColor: theme.primaryColor.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  ),
                  child: Slider(
                    value: _radius.clamp(500, 25000),
                    min: 500,
                    max: 25000,
                    divisions: 49,
                    onChanged: (value) {
                      setState(() {
                        _radius = value;
                      });
                      // DON'T update provider here - wait for Apply
                    },
                  ),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('500m', style: TextStyle(color: Colors.grey.shade600)),
                    Text('25 km', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                
                // Quick options - Only update local state
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildQuickOption('1 km', 1000),
                    _buildQuickOption('5 km', 5000),
                    _buildQuickOption('10 km', 10000),
                    _buildQuickOption('15 km', 15000),
                    _buildQuickOption('25 km', 25000),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.provider.updateSearchRadius(_radius);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Radius Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildQuickOption(String label, double radius) {
    final isSelected = _radius == radius;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _radius = radius;
        });
        // DON'T update provider here - wait for Apply
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primaryColor : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Amenities filter bottom sheet
class _AmenitiesFilterSheet extends StatefulWidget {
  final ParkingProvider provider;
  
  const _AmenitiesFilterSheet({required this.provider});
  
  @override
  State<_AmenitiesFilterSheet> createState() => _AmenitiesFilterSheetState();
}

class _AmenitiesFilterSheetState extends State<_AmenitiesFilterSheet> {
  late List<String> _selectedAmenities;
  
  final Map<String, IconData> _amenityIcons = {
    'covered': Icons.roofing,
    'cctv': Icons.videocam,
    'security': Icons.security,
    'ev_charging': Icons.ev_station,
    'handicap': Icons.accessible,
    'valet': Icons.person,
    '24_7': Icons.access_time,
    'restroom': Icons.wc,
    'lighting': Icons.lightbulb,
    'car_wash': Icons.local_car_wash,
  };
  
  @override
  void initState() {
    super.initState();
    _selectedAmenities = List.from(widget.provider.selectedAmenities);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_parking, color: theme.primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'Amenities',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_selectedAmenities.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedAmenities.clear();
                          });
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select preferred parking features',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppConfig.parkingAmenities.map((amenity) {
                  final isSelected = _selectedAmenities.contains(amenity);
                  return _buildAmenityChip(amenity, isSelected, theme);
                }).toList(),
              ),
            ),
          ),
          
          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.provider.updateSelectedAmenities(_selectedAmenities);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedAmenities.isEmpty 
                      ? 'Show All Results' 
                      : 'Apply ${_selectedAmenities.length} Filter${_selectedAmenities.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAmenityChip(String amenity, bool isSelected, ThemeData theme) {
    final displayName = amenity.replaceAll('_', ' ').toUpperCase();
    final icon = _amenityIcons[amenity] ?? Icons.check;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedAmenities.remove(amenity);
          } else {
            _selectedAmenities.add(amenity);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              displayName,
              style: TextStyle(
                color: isSelected ? theme.primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle,
                size: 18,
                color: theme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Vehicle type filter bottom sheet
class _VehicleTypeFilterSheet extends StatefulWidget {
  final ParkingProvider provider;
  
  const _VehicleTypeFilterSheet({required this.provider});
  
  @override
  State<_VehicleTypeFilterSheet> createState() => _VehicleTypeFilterSheetState();
}

class _VehicleTypeFilterSheetState extends State<_VehicleTypeFilterSheet> {
  late List<String> _selectedTypes;
  
  final List<Map<String, dynamic>> _vehicleTypes = [
    {'key': 'car', 'name': 'Car', 'icon': Icons.directions_car},
    {'key': 'motorcycle', 'name': 'Motorcycle', 'icon': Icons.two_wheeler},
    {'key': 'bicycle', 'name': 'Bicycle', 'icon': Icons.pedal_bike},
    {'key': 'suv', 'name': 'SUV', 'icon': Icons.directions_car},
    {'key': 'truck', 'name': 'Truck', 'icon': Icons.local_shipping},
    {'key': 'bus', 'name': 'Bus', 'icon': Icons.directions_bus},
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedTypes = List.from(widget.provider.selectedVehicleTypes);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Vehicle Type',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Find parking for your vehicle',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _vehicleTypes.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicleTypes[index];
                    final isSelected = _selectedTypes.contains(vehicle['key']);
                    return _buildVehicleCard(vehicle, isSelected, theme);
                  },
                ),
              ],
            ),
          ),
          
          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.provider.updateSelectedVehicleTypes(_selectedTypes);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedTypes.isEmpty 
                      ? 'Show All Vehicles' 
                      : 'Apply Filter',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVehicleCard(Map<String, dynamic> vehicle, bool isSelected, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTypes.remove(vehicle['key']);
          } else {
            _selectedTypes.add(vehicle['key']);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              vehicle['icon'],
              size: 36,
              color: isSelected ? theme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              vehicle['name'],
              style: TextStyle(
                color: isSelected ? theme.primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

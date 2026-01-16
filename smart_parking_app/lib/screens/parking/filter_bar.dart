// lib/screens/parking/filter_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';

class ParkingFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(context, 'Sort By', Icons.sort, () => _showSortOptions(context)),
          SizedBox(width: 8),
          _buildFilterChip(context, 'Price', Icons.attach_money, () => _showPriceFilter(context)),
          SizedBox(width: 8),
          _buildFilterChip(context, 'Distance', Icons.location_on, () => _showDistanceFilter(context)),
          SizedBox(width: 8),
          _buildFilterChip(context, 'Amenities', Icons.local_parking, () => _showAmenitiesFilter(context)),
          SizedBox(width: 8),
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              return FilterChip(
                label: Text('Available Only'),
                selected: provider.showAvailableOnly,
                onSelected: (bool selected) {
                  provider.toggleAvailabilityFilter();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ParkingProvider>(
          builder: (context, provider, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Sort By'),
                  trailing: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                RadioListTile<String>(
                  title: Text('Distance'),
                  value: 'distance',
                  groupValue: provider.sortBy,
                  onChanged: (value) {
                    provider.updateSortBy(value!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: Text('Price'),
                  value: 'price',
                  groupValue: provider.sortBy,
                  onChanged: (value) {
                    provider.updateSortBy(value!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: Text('Rating'),
                  value: 'rating',
                  groupValue: provider.sortBy,
                  onChanged: (value) {
                    provider.updateSortBy(value!);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPriceFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ParkingProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price Range (per hour)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 16),
                  RangeSlider(
                    values: RangeValues(provider.minPrice, provider.maxPrice),
                    min: 0,
                    max: 500, // Assuming max price 500
                    divisions: 50,
                    labels: RangeLabels(
                      '${AppConfig.currencySymbol}${provider.minPrice.round()}',
                      '${AppConfig.currencySymbol}${provider.maxPrice.round()}',
                    ),
                    onChanged: (RangeValues values) {
                      provider.updatePriceRange(values.start, values.end);
                    },
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppConfig.currencySymbol}0'),
                      Text('${AppConfig.currencySymbol}500+'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDistanceFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ParkingProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search Radius', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 16),
                  Slider(
                    value: provider.searchRadius,
                    min: 500,
                    max: 10000,
                    divisions: 19,
                    label: '${(provider.searchRadius / 1000).toStringAsFixed(1)} km',
                    onChanged: (double value) {
                      provider.updateSearchRadius(value);
                      provider.findNearbyParkingSpots(
                        provider.currentLocation?.latitude ?? 0,
                        provider.currentLocation?.longitude ?? 0,
                      );
                    },
                  ),
                  Text('${(provider.searchRadius / 1000).toStringAsFixed(1)} km'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAmenitiesFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ParkingProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: AppConfig.parkingAmenities.map((amenity) {
                      final isSelected = provider.selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity.replaceAll('_', ' ').toUpperCase()),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          List<String> newAmenities = List.from(provider.selectedAmenities);
                          if (selected) {
                            newAmenities.add(amenity);
                          } else {
                            newAmenities.remove(amenity);
                          }
                          provider.updateSelectedAmenities(newAmenities);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

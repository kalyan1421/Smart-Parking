
// // lib/screens/maps/traffic_view_screen.dart - Traffic visualization
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_parking_app/config/constants.dart';
// import 'package:smart_parking_app/config/theme.dart';
// import 'package:smart_parking_app/models/traffic_data.dart';
// import 'package:smart_parking_app/providers/location_provider.dart';
// import 'package:smart_parking_app/providers/traffic_provider.dart';
// import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

// class TrafficViewScreen extends StatefulWidget {
//   @override
//   _TrafficViewScreenState createState() => _TrafficViewScreenState();
// }

// class _TrafficViewScreenState extends State<TrafficViewScreen> {
//   GoogleMapController? _mapController;
//   Set<Circle> _trafficCircles = {};
//   bool _isLoading = false;
  
//   @override
//   void initState() {
//     super.initState();
//     _loadTrafficData();
//   }
  
//   Future<void> _loadTrafficData() async {
//     setState(() {
//       _isLoading = true;
//     });
    
//     try {
//       final locationProvider = Provider.of<LocationProvider>(context, listen: false);
//       final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      
//       if (!locationProvider.hasLocation) {
//         await locationProvider.getCurrentLocation();
//       }
      
//       await trafficProvider.loadTrafficDataNearLocation(
//         locationProvider.latitude,
//         locationProvider.longitude,
//         10.0 // 10 km radius
//       );
      
//       _createTrafficCircles();
//     } catch (e) {
//       print('Error loading traffic data: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
  
//   void _createTrafficCircles() {
//     final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
//     final Set<Circle> circles = {};
    
//     for (final trafficData in trafficProvider.trafficDataList) {
//       final circle = Circle(
//         circleId: CircleId(trafficData.id.toHexString()),
//         center: LatLng(trafficData.latitude, trafficData.longitude),
//         radius: 300, // 300 meters
//         fillColor: _getCongestionColor(trafficData.congestionLevel).withOpacity(0.3),
//         strokeColor: _getCongestionColor(trafficData.congestionLevel),
//         strokeWidth: 2,
//       );
      
//       circles.add(circle);
//     }
    
//     setState(() {
//       _trafficCircles = circles;
//     });
//   }
  
//   Color _getCongestionColor(CongestionLevel level) {
//     switch (level) {
//       case CongestionLevel.low:
//         return AppTheme.lightTrafficColor;
//       case CongestionLevel.moderate:
//         return AppTheme.moderateTrafficColor;
//       case CongestionLevel.high:
//         return AppTheme.heavyTrafficColor;
//     }
//   }
  
//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;
//     _centerOnUser();
//   }
  
//   Future<void> _centerOnUser() async {
//     if (_mapController != null) {
//       final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
//       if (locationProvider.hasLocation) {
//         _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: LatLng(
//                 locationProvider.latitude,
//                 locationProvider.longitude,
//               ),
//               zoom: 13.0,
//             ),
//           ),
//         );
//       }
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     final locationProvider = Provider.of<LocationProvider>(context);
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Traffic Conditions'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadTrafficData,
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Map
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: LatLng(
//                 locationProvider.latitude,
//                 locationProvider.longitude,
//               ),
//               zoom: 13.0,
//             ),
//             onMapCreated: _onMapCreated,
//             myLocationEnabled: true,
//             myLocationButtonEnabled: true,
//             circles: _trafficCircles,
//             mapToolbarEnabled: false,
//             zoomControlsEnabled: false,
//             compassEnabled: true,
//           ),
          
//           // Loading indicator
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.3),
//               child: Center(
//                 child: LoadingIndicator(),
//               ),
//             ),
          
//           // Legend
//           Positioned(
//             left: 16,
//             bottom: 16,
//             child: Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Traffic Legend',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     _buildLegendItem(AppTheme.lightTrafficColor, 'Light Traffic'),
//                     SizedBox(height: 4),
//                     _buildLegendItem(AppTheme.moderateTrafficColor, 'Moderate Traffic'),
//                     SizedBox(height: 4),
//                     _buildLegendItem(AppTheme.heavyTrafficColor, 'Heavy Traffic'),
//                   ],
//                 ),
//               ),
//             ),
//           ),
          
//           // Center on user button
//           Positioned(
//             right: 16,
//             bottom: 16,
//             child: FloatingActionButton(
//               heroTag: 'centerOnUser',
//               mini: true,
//               backgroundColor: Colors.white,
//               onPressed: _centerOnUser,
//               child: Icon(
//                 Icons.my_location,
//                 color: Theme.of(context).primaryColor,
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           // TODO: Navigate to traffic report screen
//         },
//         label: Text('Report Traffic'),
//         icon: Icon(Icons.report_problem),
//       ),
//     );
//   }
  
//   Widget _buildLegendItem(Color color, String label) {
//     return Row(
//       children: [
//         Container(
//           width: 16,
//           height: 16,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//         ),
//         SizedBox(width: 8),
//         Text(label),
//       ],
//     );
//   }
// }

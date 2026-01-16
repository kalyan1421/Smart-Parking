// lib/screens/admin/admin_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class AdminMapScreen extends StatefulWidget {
  @override
  _AdminMapScreenState createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);

    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }

    await parkingProvider.loadAllParkingSpots();
    _updateMarkers();
  }

  void _updateMarkers() {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final spots = parkingProvider.allParkingSpots;

    Set<Marker> markers = {};

    for (final spot in spots) {
      markers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: 'Available: ${spot.availableSpots}/${spot.totalSpots}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          spot.availableSpots > 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final parkingProvider = Provider.of<ParkingProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Parking Spots Map (Admin)')),
      body: parkingProvider.isLoading
          ? Center(child: LoadingIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  locationProvider.currentLocation?.latitude ?? 0,
                  locationProvider.currentLocation?.longitude ?? 0,
                ),
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
            ),
    );
  }
}

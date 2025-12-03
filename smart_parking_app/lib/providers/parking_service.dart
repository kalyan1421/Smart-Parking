// lib/providers/parking_service.dart - Mock parking data service
import '../models/parking_spot.dart';
import '../config/app_config.dart';

class ParkingService {
  static List<ParkingSpot> _mockParkingSpots = [];

  // Initialize mock parking spots for testing
  static Future<void> initializeMockData() async {
    if (_mockParkingSpots.isNotEmpty) return; // Already initialized

    _mockParkingSpots.addAll([
      ParkingSpot(
        id: 'spot001',
        name: 'Downtown Parking Garage',
        description: 'Covered parking in the heart of downtown',
        address: '123 Main St, Downtown',
        latitude: 37.7749,
        longitude: -122.4194,
        totalSpots: 150,
        availableSpots: 42,
        pricePerHour: 4.50,
        amenities: ['covered', 'security', 'electric_charging'],
        operatingHours: {
          'monday': {'open': '06:00', 'close': '22:00'},
          'tuesday': {'open': '06:00', 'close': '22:00'},
          'wednesday': {'open': '06:00', 'close': '22:00'},
          'thursday': {'open': '06:00', 'close': '22:00'},
          'friday': {'open': '06:00', 'close': '23:00'},
          'saturday': {'open': '08:00', 'close': '23:00'},
          'sunday': {'open': '08:00', 'close': '21:00'},
        },
        vehicleTypes: ['car', 'electric_car'],
        ownerId: 'owner001',
        geoPoint: null, // Will be set by GeoFlutterFire
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: true,
      ),
      ParkingSpot(
        id: 'spot002',
        name: 'Main Street Lot',
        description: 'Convenient open-air parking near shopping',
        address: '456 Main St, Shopping District',
        latitude: 37.7750,
        longitude: -122.4180,
        totalSpots: 80,
        availableSpots: 15,
        pricePerHour: 3.00,
        amenities: ['cctv', '24_7_access'],
        operatingHours: {
          'monday': {'open': '00:00', 'close': '23:59'},
          'tuesday': {'open': '00:00', 'close': '23:59'},
          'wednesday': {'open': '00:00', 'close': '23:59'},
          'thursday': {'open': '00:00', 'close': '23:59'},
          'friday': {'open': '00:00', 'close': '23:59'},
          'saturday': {'open': '00:00', 'close': '23:59'},
          'sunday': {'open': '00:00', 'close': '23:59'},
        },
        vehicleTypes: ['car', 'motorcycle'],
        ownerId: 'owner002',
        geoPoint: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: true,
      ),
      ParkingSpot(
        id: 'spot003',
        name: 'City Center Parking',
        description: 'Premium parking with valet service',
        address: '789 Center Ave, City Center',
        latitude: 37.7760,
        longitude: -122.4170,
        totalSpots: 200,
        availableSpots: 75,
        pricePerHour: 6.00,
        amenities: ['valet', 'covered', 'security', 'elevator'],
        operatingHours: {
          'monday': {'open': '05:00', 'close': '23:00'},
          'tuesday': {'open': '05:00', 'close': '23:00'},
          'wednesday': {'open': '05:00', 'close': '23:00'},
          'thursday': {'open': '05:00', 'close': '23:00'},
          'friday': {'open': '05:00', 'close': '24:00'},
          'saturday': {'open': '06:00', 'close': '24:00'},
          'sunday': {'open': '07:00', 'close': '22:00'},
        },
        vehicleTypes: ['car', 'electric_car', 'suv'],
        ownerId: 'owner003',
        geoPoint: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: true,
      ),
      ParkingSpot(
        id: 'spot004',
        name: 'Budget Parking Lot',
        description: 'Affordable parking for budget-conscious drivers',
        address: '321 Budget St, Outskirts',
        latitude: 37.7730,
        longitude: -122.4210,
        totalSpots: 50,
        availableSpots: 30,
        pricePerHour: 2.00,
        amenities: ['lighting'],
        operatingHours: {
          'monday': {'open': '06:00', 'close': '20:00'},
          'tuesday': {'open': '06:00', 'close': '20:00'},
          'wednesday': {'open': '06:00', 'close': '20:00'},
          'thursday': {'open': '06:00', 'close': '20:00'},
          'friday': {'open': '06:00', 'close': '21:00'},
          'saturday': {'open': '07:00', 'close': '21:00'},
          'sunday': {'open': '08:00', 'close': '19:00'},
        },
        vehicleTypes: ['car', 'motorcycle', 'bicycle'],
        ownerId: 'owner004',
        geoPoint: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: false,
      ),
      ParkingSpot(
        id: 'spot005',
        name: 'Electric Vehicle Hub',
        description: 'Specialized parking for electric vehicles with charging stations',
        address: '555 Green Ave, Tech District',
        latitude: 37.7770,
        longitude: -122.4160,
        totalSpots: 60,
        availableSpots: 25,
        pricePerHour: 5.50,
        amenities: ['electric_charging', 'covered', 'security', 'cctv'],
        operatingHours: {
          'monday': {'open': '00:00', 'close': '23:59'},
          'tuesday': {'open': '00:00', 'close': '23:59'},
          'wednesday': {'open': '00:00', 'close': '23:59'},
          'thursday': {'open': '00:00', 'close': '23:59'},
          'friday': {'open': '00:00', 'close': '23:59'},
          'saturday': {'open': '00:00', 'close': '23:59'},
          'sunday': {'open': '00:00', 'close': '23:59'},
        },
        vehicleTypes: ['electric_car'],
        ownerId: 'owner005',
        geoPoint: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: true,
      ),
    ]);
  }

  // Get all mock parking spots
  static List<ParkingSpot> getAllParkingSpots() {
    return List.from(_mockParkingSpots);
  }

  // Get parking spots near a location (simplified for mock data)
  static List<ParkingSpot> getParkingSpotsNear(
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    // For mock data, just return all spots
    // In a real implementation, this would filter by distance
    return getAllParkingSpots();
  }

  // Update parking spot availability
  static Future<bool> updateParkingSpotAvailability(
    String spotId,
    int newAvailableSpots,
  ) async {
    try {
      final spotIndex = _mockParkingSpots.indexWhere((spot) => spot.id == spotId);
      if (spotIndex != -1) {
        final spot = _mockParkingSpots[spotIndex];
        _mockParkingSpots[spotIndex] = ParkingSpot(
          id: spot.id,
          name: spot.name,
          description: spot.description,
          address: spot.address,
          latitude: spot.latitude,
          longitude: spot.longitude,
          totalSpots: spot.totalSpots,
          availableSpots: newAvailableSpots,
          pricePerHour: spot.pricePerHour,
          amenities: spot.amenities,
          operatingHours: spot.operatingHours,
          vehicleTypes: spot.vehicleTypes,
          ownerId: spot.ownerId,
          geoPoint: spot.geoPoint,
          createdAt: spot.createdAt,
          updatedAt: DateTime.now(),
          isVerified: spot.isVerified,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Add a new parking spot
  static Future<bool> addParkingSpot(ParkingSpot spot) async {
    try {
      _mockParkingSpots.add(spot);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Remove a parking spot
  static Future<bool> removeParkingSpot(String spotId) async {
    try {
      _mockParkingSpots.removeWhere((spot) => spot.id == spotId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
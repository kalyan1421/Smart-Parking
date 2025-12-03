// // lib/repositories/parking_repository.dart
// import 'package:mongo_dart/mongo_dart.dart';
// import 'package:smart_parking_app/config/app_config.dart';
// import 'package:smart_parking_app/core/database/database_service.dart';
// import 'package:smart_parking_app/models/parking_spot.dart';
// import 'package:smart_parking_app/models/booking.dart';
// import 'package:smart_parking_app/models/user.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class ParkingRepository {
//   // Database collections
//   DbCollection get _parkingSpotsCollection => 
//       DatabaseService.db.collection('parkingSpots');
  
//   DbCollection get _bookingsCollection => 
//       DatabaseService.db.collection('bookings');
  
//   DbCollection get _usersCollection => 
//       DatabaseService.db.collection('users');
  
//   DbCollection get _vehiclesCollection => 
//       DatabaseService.db.collection('vehicles');
  
//   // Find nearby parking spots using MongoDB geospatial queries
//   Future<List<ParkingSpot>> findNearbyParkingSpots(
//     double latitude, 
//     double longitude,
//     double radius
//   ) async {
//     try {
//       // Find parking spots in our database using geospatial query
//       final spotDocs = await _parkingSpotsCollection.find({
//         'location': {
//           '\$nearSphere': {
//             '\$geometry': {
//               'type': 'Point',
//               'coordinates': [longitude, latitude]
//             },
//             '\$maxDistance': radius / 1000 // Convert to km
//           }
//         }
//       }).toList();
      
//       List<ParkingSpot> results = spotDocs.map((doc) => ParkingSpot.fromJson(doc)).toList();
      
//       // If we don't have enough results, create some sample parking spots
//       if (results.isEmpty) {
//         results = await _generateDefaultParkingSpots(latitude, longitude);
//       }
      
//       return results;
//     } catch (e) {
//       print('Error finding nearby parking spots: $e');
//       rethrow;
//     }
//   }
  
//   // Generate default parking spots around a location if none exist in DB
//   Future<List<ParkingSpot>> _generateDefaultParkingSpots(double latitude, double longitude) async {
//     List<ParkingSpot> spots = [];
    
//     // Create a few parking spots at slight offsets from user location
//     final offsets = [
//       {'lat': 0.001, 'lng': 0.001, 'name': 'Central Parking'},
//       {'lat': -0.001, 'lng': 0.002, 'name': 'City Park'},
//       {'lat': 0.002, 'lng': -0.001, 'name': 'Main Street Parking'},
//       {'lat': -0.002, 'lng': -0.002, 'name': 'Downtown Garage'},
//       {'lat': 0.003, 'lng': 0.0, 'name': 'North Parking'},
//     ];
    
//     for (var i = 0; i < offsets.length; i++) {
//       final offset = offsets[i];
//       final spotLat = latitude + 1.2;
//       final spotLng = longitude + 22.3;
      
//       // Attempt to get address from coordinates (could be replaced with a real geocoding service)
//       final address = await _getAddressFromCoordinates(spotLat, spotLng) ?? 
//                       '${(i+1)*100} Main St, City';
      
//       final spot = ParkingSpot(
//         id: ObjectId(),
//         name: offset['name'].toString(),
//         address: address,
//         latitude: spotLat,
//         longitude: spotLng,
//         totalSpots: 20 + (i * 5),
//         availableSpots: 10 + (i * 2),
//         pricePerHour: 2.0 + (i * 0.5),
//         hasElectricCharger: i % 2 == 0,
//         hasRoof: i % 3 == 0,
//         isHandicapAccessible: i % 2 == 1,
//         description: 'Convenient parking location with ${i % 2 == 0 ? 'EV charging' : 'covered spots'} available.',
//         rating: 3.5 + (i * 0.3) % 1.5,
//         ratingCount: 10 + (i * 12),
//       );
      
//       // Save to database
//       final spotJson = spot.toJson();
//       spotJson['isCustom'] = true;
//       spotJson['location'] = {
//         'type': 'Point',
//         'coordinates': [spot.longitude, spot.latitude]
//       };
      
//       await _parkingSpotsCollection.insert(spotJson);
//       spots.add(spot);
//     }
    
//     return spots;
//   }
  
//   // Simple function to get address from coordinates
//   // In a real app, use a geocoding service like Google/Mapbox
//   Future<String?> _getAddressFromCoordinates(double lat, double lng) async {
//     try {
//       // This is a sample approach - replace with your preferred geocoding service
//       final response = await http.get(
//         Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
//         headers: {'User-Agent': 'SmartParkingApp/1.0'},
//       );
      
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         return data['display_name'];
//       }
//       return null;
//     } catch (e) {
//       print('Error getting address: $e');
//       return null;
//     }
//   }
  
//   // Book a parking spot
//   Future<Booking> bookParkingSpot({
//     required String userId,
//     required ObjectId parkingSpotId,
//     required DateTime startTime,
//     required DateTime endTime,
//     required String vehicleId,
//   }) async {
//     try {
//       // Get the parking spot
//       final spotDoc = await _parkingSpotsCollection.findOne(
//         where.id(parkingSpotId)
//       );
      
//       if (spotDoc == null) {
//         throw Exception('Parking spot not found');
//       }
      
//       final spot = ParkingSpot.fromJson(spotDoc);
      
//       // Check if spot is available
//       if (spot.availableSpots <= 0) {
//         throw Exception('No available spots at this location');
//       }
      
//       // Get the vehicle details
//       final vehicleDoc = await _vehiclesCollection.findOne(
//         where.eq('_id', ObjectId.parse(vehicleId))
//       );
      
//       if (vehicleDoc == null) {
//         throw Exception('Vehicle not found');
//       }
      
//       // Calculate total price
//       final durationHours = endTime.difference(startTime).inMinutes / 60.0;
//       final totalPrice = spot.pricePerHour * durationHours;
      
//       // Create the booking
//       final booking = Booking(
//         id: ObjectId(),
//         userId: userId,
//         parkingSpotId: parkingSpotId,
//         parkingSpotName: spot.name,
//         parkingSpotAddress: spot.address,
//         bookingTime: DateTime.now(),
//         startTime: startTime,
//         endTime: endTime,
//         vehicleId: vehicleId,
//         vehiclePlate: vehicleDoc['licensePlate'],
//         totalPrice: totalPrice,
//         status: BookingStatus.confirmed,
//         // Generate a unique QR code string
//         qrCode: 'PARK-${ObjectId().toHexString()}'
//       );
      
//       // Save booking to database
//       await _bookingsCollection.insert(booking.toJson());
      
//       // Update available spots count
//       await _parkingSpotsCollection.update(
//         where.id(parkingSpotId),
//         modify.set('availableSpots', spot.availableSpots - 1)
//       );
      
//       // Update user's bookings
//       await _usersCollection.update(
//         where.eq('_id', ObjectId.parse(userId)),
//         modify.push('bookingIds', booking.id)
//       );
      
//       return booking;
//     } catch (e) {
//       print('Error booking parking spot: $e');
//       rethrow;
//     }
//   }
  
//   // Cancel a booking
//   Future<bool> cancelBooking(ObjectId bookingId) async {
//     try {
//       // Get the booking
//       final bookingDoc = await _bookingsCollection.findOne(
//         where.id(bookingId)
//       );
      
//       if (bookingDoc == null) {
//         throw Exception('Booking not found');
//       }
      
//       final booking = Booking.fromJson(bookingDoc);
      
//       // Check if booking can be cancelled (not already active or completed)
//       if (booking.status == BookingStatus.active || 
//           booking.status == BookingStatus.completed) {
//         throw Exception('Cannot cancel an active or completed booking');
//       }
      
//       // Update booking status
//       await _bookingsCollection.update(
//         where.id(bookingId),
//         modify.set('status', BookingStatus.cancelled.index)
//       );
      
//       // Restore available parking spot
//       await _parkingSpotsCollection.update(
//         where.id(booking.parkingSpotId),
//         modify.inc('availableSpots', 1)
//       );
      
//       // Note: We don't remove the booking from user's bookingIds
//       // to keep history of all bookings
      
//       return true;
//     } catch (e) {
//       print('Error cancelling booking: $e');
//       return false;
//     }
//   }
  
//   // Get user's bookings
//   Future<List<Booking>> getUserBookings(String userId) async {
//     try {
//       final bookingDocs = await _bookingsCollection.find(
//         where.eq('userId', userId)
//       ).toList();
      
//       return bookingDocs.map((doc) => Booking.fromJson(doc)).toList();
//     } catch (e) {
//       print('Error getting user bookings: $e');
//       rethrow;
//     }
//   }
  
//   // Add a custom parking spot (for admin or partner usage)
//   Future<ParkingSpot> addCustomParkingSpot(ParkingSpot spot) async {
//     try {
//       // Create a new parking spot
//       final spotWithId = spot.copyWith(
//         id: ObjectId(),
//       );
      
//       // Add custom flag
//       final spotJson = spotWithId.toJson();
//       spotJson['isCustom'] = true;
//       spotJson['location'] = {
//         'type': 'Point',
//         'coordinates': [spot.longitude, spot.latitude]
//       };
      
//       // Save to database
//       await _parkingSpotsCollection.insert(spotJson);
//       return spotWithId;
//     } catch (e) {
//       print('Error adding custom parking spot: $e');
//       rethrow;
//     }
//   }
  
//   // Update a parking spot's details
//   Future<ParkingSpot> updateParkingSpot(ParkingSpot updatedSpot) async {
//     try {
//       final spotJson = updatedSpot.toJson();
      
//       // Ensure the location field is updated
//       spotJson['location'] = {
//         'type': 'Point',
//         'coordinates': [updatedSpot.longitude, updatedSpot.latitude]
//       };
      
//       // Update in database
//       await _parkingSpotsCollection.update(
//         where.id(updatedSpot.id),
//         spotJson
//       );
      
//       return updatedSpot;
//     } catch (e) {
//       print('Error updating parking spot: $e');
//       rethrow;
//     }
//   }
  
//   // Get details of a specific parking spot
//   Future<ParkingSpot?> getParkingSpotDetails(ObjectId spotId) async {
//     try {
//       final spotDoc = await _parkingSpotsCollection.findOne(
//         where.id(spotId)
//       );
      
//       if (spotDoc == null) {
//         return null;
//       }
      
//       return ParkingSpot.fromJson(spotDoc);
//     } catch (e) {
//       print('Error getting parking spot details: $e');
//       rethrow;
//     }
//   }
  
//   // Method to search for parking spots by name or address
//   Future<List<ParkingSpot>> searchParkingSpots(String query) async {
//     try {
//       // Simple text search
//       final spotDocs = await _parkingSpotsCollection.find(
//         where.match('name', query).or(where.match('address', query))
//       ).toList();
      
//       return spotDocs.map((doc) => ParkingSpot.fromJson(doc)).toList();
//     } catch (e) {
//       print('Error searching parking spots: $e');
//       rethrow;
//     }
//   }
// }
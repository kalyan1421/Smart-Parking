// // lib/screens/parking/booking_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_parking_app/config/app_config.dart';
// import 'package:smart_parking_app/models/parking_spot.dart';
// import 'package:smart_parking_app/models/vehicle.dart';
// import 'package:smart_parking_app/models/booking.dart';
// import 'package:smart_parking_app/providers/auth_provider.dart';
// import 'package:smart_parking_app/providers/parking_provider.dart';
// import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
// import 'package:intl/intl.dart';
// class BookingScreen extends StatefulWidget {
//   final ParkingSpot parkingSpot;
  
//   BookingScreen({required this.parkingSpot});
  
//   @override
//   _BookingScreenState createState() => _BookingScreenState();
// }

// class _BookingScreenState extends State<BookingScreen> {
//   DateTime _startDate = DateTime.now().add(Duration(minutes: 15));
//   DateTime _endDate = DateTime.now().add(Duration(hours: 2));
//   Vehicle? _selectedVehicle;
//   List<Vehicle> _userVehicles = [];
//   bool _isLoading = false;
//   String? _error;
//   double _totalCost = 0;
//   List bjectId =[];
  
//   @override
//   void initState() {
//     super.initState();
//     _calculateTotalCost();
//     _loadUserVehicles();
//   }
  
//   Future<void> _loadUserVehicles() async {
//     setState(() => _isLoading = true);
    
//     try {
//       // Normally you'd load this from a vehicle repository
//       // For this example, we'll use mock data
//       final userId = Provider.of<AuthProvider>(context, listen: false).currentUser!.id.toHexString();
      
//       // Mock data - in a real app, this would come from a database
//       // _userVehicles = [
//       //   Vehicle(
//       //     id: ObjectId(),
//       //     userId: userId,
//       //     licensePlate: 'ABC123',
//       //     make: 'Toyota',
//       //     model: 'Corolla',
//       //     type: VehicleType.sedan,
//       //     color: 'Blue',
//       //     isDefault: true,
//       //   ),
//       //   Vehicle(
//       //     id: ObjectId(),
//       //     userId: userId,
//       //     licensePlate: 'XYZ789',
//       //     make: 'Tesla',
//       //     model: 'Model 3',
//       //     type: VehicleType.electric,
//       //     color: 'Red',
//       //     isElectric: true,
//       //   ),
//       // ];
      
//       // Set default vehicle
//       _selectedVehicle = _userVehicles.firstWhere(
//         (v) => v.isDefault, 
//         orElse: () => _userVehicles.first
//       );
      
//       setState(() => _isLoading = false);
//     } catch (e) {
//       print('Error loading vehicles: $e');
//       setState(() {
//         _isLoading = false;
//         _error = 'Failed to load vehicles: $e';
//       });
//     }
//   }
  
//   void _calculateTotalCost() {
//     final durationHours = _endDate.difference(_startDate).inMinutes / 60.0;
//     _totalCost = widget.parkingSpot.pricePerHour * durationHours;
//   }
  
//   Future<void> _selectStartDateTime() async {
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: _startDate,
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(Duration(days: 7)),
//     );
    
//     if (pickedDate != null) {
//       final TimeOfDay? pickedTime = await showTimePicker(
//         context: context,
//         initialTime: TimeOfDay.fromDateTime(_startDate),
//       );
      
//       if (pickedTime != null) {
//         setState(() {
//           _startDate = DateTime(
//             pickedDate.year,
//             pickedDate.month,
//             pickedDate.day,
//             pickedTime.hour,
//             pickedTime.minute,
//           );
          
//           // Make sure end date is after start date
//           if (_endDate.isBefore(_startDate.add(Duration(minutes: 30)))) {
//             _endDate = _startDate.add(Duration(hours: 2));
//           }
          
//           _calculateTotalCost();
//         });
//       }
//     }
//   }
  
//   Future<void> _selectEndDateTime() async {
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: _endDate,
//       firstDate: _startDate,
//       lastDate: _startDate.add(Duration(days: 7)),
//     );
    
//     if (pickedDate != null) {
//       final TimeOfDay? pickedTime = await showTimePicker(
//         context: context,
//         initialTime: TimeOfDay.fromDateTime(_endDate),
//       );
      
//       if (pickedTime != null) {
//         setState(() {
//           _endDate = DateTime(
//             pickedDate.year,
//             pickedDate.month,
//             pickedDate.day,
//             pickedTime.hour,
//             pickedTime.minute,
//           );
          
//           _calculateTotalCost();
//         });
//       }
//     }
//   }
  
//   Future<void> _bookParkingSpot() async {
//     if (_selectedVehicle == null) {
//       setState(() {
//         _error = 'Please select a vehicle';
//       });
//       return;
//     }
    
//     // Check minimum duration (30 minutes)
//     if (_endDate.difference(_startDate).inMinutes < 30) {
//       setState(() {
//         _error = 'Booking must be at least 30 minutes';
//       });
//       return;
//     }
    
//     // Check maximum duration (24 hours or configured value)
//     if (_endDate.difference(_startDate).inHours > AppConfig.maxBookingDurationHours) {
//       setState(() {
//         _error = 'Booking cannot exceed ${AppConfig.maxBookingDurationHours} hours';
//       });
//       return;
//     }
    
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });
    
//     try {
//       final userId = Provider.of<AuthProvider>(context, listen: false).currentUser!.id.toHexString();
//       final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      
//       final booking = await parkingProvider.bookParkingSpot(
//         userId: userId,
//         parkingSpotId: widget.parkingSpot.id,
//         startTime: _startDate,
//         endTime: _endDate,
//         vehicleId: _selectedVehicle!.id.toHexString(),
//       );
      
//       if (booking != null) {
//         // Show confirmation and navigate to booking details
//         await _showBookingConfirmation(booking);
//       } else {
//         setState(() {
//           _error = 'Failed to create booking';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error booking parking spot: $e');
//       setState(() {
//         _error = 'Error booking: $e';
//         _isLoading = false;
//       });
//     }
//   }
  
//   Future<void> _showBookingConfirmation(Booking booking) async {
//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.check_circle, color: Colors.green),
//               SizedBox(width: 8),
//               Text('Booking Confirmed'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Your parking spot has been booked successfully!'),
//               SizedBox(height: 16),
//               _buildConfirmationItem(
//                 'Location:', 
//                 booking.parkingSpotName
//               ),
//               _buildConfirmationItem(
//                 'Date:', 
//                 DateFormat('EEE, MMM d, yyyy').format(booking.startTime)
//               ),
//               _buildConfirmationItem(
//                 'Time:', 
//                 '${DateFormat('h:mm a').format(booking.startTime)} - ${DateFormat('h:mm a').format(booking.endTime)}'
//               ),
//               _buildConfirmationItem(
//                 'Vehicle:', 
//                 booking.vehiclePlate
//               ),
//               _buildConfirmationItem(
//                 'Total:', 
//                 '${AppConfig.currencySymbol}${booking.totalPrice.toStringAsFixed(2)}'
//               ),
              
//               if (booking.qrCode != null)
//                 Padding(
//                   padding: EdgeInsets.only(top: 16),
//                   child: Center(
//                     child: Column(
//                       children: [
//                         Text(
//                           'Show this code when you arrive:',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         SizedBox(height: 8),
//                         Container(
//                           width: 150,
//                           height: 150,
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                           ),
//                           child: Center(
//                             child: Text(
//                               booking.qrCode!,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context); // Close dialog
//                 Navigator.pop(context); // Return to previous screen
//                 Navigator.pushNamed(context, '/bookings'); // Go to bookings screen
//               },
//               child: Text('VIEW MY BOOKINGS'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context); // Close dialog
//                 Navigator.pop(context); // Return to previous screen
//               },
//               child: Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }
  
//   Widget _buildConfirmationItem(String label, String value) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 80,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(value),
//           ),
//         ],
//       ),
//     );
//   }
  
//   String _formatDuration(Duration duration) {
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;
    
//     if (hours > 0) {
//       return '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes min' : ''}';
//     } else {
//       return '$minutes minutes';
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Book Parking'),
//       ),
//       body: _isLoading
//           ? Center(child: LoadingIndicator())
//           : SingleChildScrollView(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // Parking spot info
//                   Card(
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             widget.parkingSpot.name,
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 4),
//                           Text(
//                             widget.parkingSpot.address,
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           Row(
//                             children: [
//                               Icon(Icons.local_parking, size: 16),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${widget.parkingSpot.availableSpots} spots available',
//                                 style: TextStyle(
//                                   color: Colors.green,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               SizedBox(width: 16),
//                               Icon(Icons.attach_money, size: 16),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${AppConfig.currencySymbol}${widget.parkingSpot.pricePerHour.toStringAsFixed(2)}/hour',
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Date and time selection
//                   Card(
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Date & Time',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 16),
                          
//                           // Start time
//                           ListTile(
//                             title: Text('Start'),
//                             subtitle: Text(
//                               DateFormat('EEE, MMM d, h:mm a').format(_startDate),
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             trailing: Icon(Icons.edit),
//                             onTap: _selectStartDateTime,
//                           ),
                          
//                           Divider(),
                          
//                           // End time
//                           ListTile(
//                             title: Text('End'),
//                             subtitle: Text(
//                               DateFormat('EEE, MMM d, h:mm a').format(_endDate),
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             trailing: Icon(Icons.edit),
//                             onTap: _selectEndDateTime,
//                           ),
                          
//                           Divider(),
                          
//                           // Duration
//                           ListTile(
//                             title: Text('Duration'),
//                             subtitle: Text(
//                               _formatDuration(_endDate.difference(_startDate)),
//                               style: TextStyle(fontSize: 16),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Vehicle selection
//                   Card(
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 'Vehicle',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               TextButton.icon(
//                                 onPressed: () {
//                                   // Navigate to add vehicle screen
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(content: Text('Add vehicle functionality would be implemented here')),
//                                   );
//                                 },
//                                 icon: Icon(Icons.add),
//                                 label: Text('ADD'),
//                               ),
//                             ],
//                           ),
//                           SizedBox(height: 8),
                          
//                           // Vehicle list
//                           ..._userVehicles.map((vehicle) => RadioListTile<Vehicle>(
//                             title: Text(vehicle.displayName),
//                             subtitle: Text(
//                               vehicle.isElectric ? 'Electric Vehicle' : '${vehicle.make} ${vehicle.model}',
//                             ),
//                             value: vehicle,
//                             groupValue: _selectedVehicle,
//                             onChanged: (value) {
//                               setState(() {
//                                 _selectedVehicle = value;
//                               });
//                             },
//                             secondary: Icon(
//                               vehicle.isElectric ? Icons.electric_car : Icons.directions_car,
//                               color: Theme.of(context).primaryColor,
//                             ),
//                           )),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   // Error message
//                   if (_error != null)
//                     Container(
//                       margin: EdgeInsets.only(top: 16),
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.red.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.red),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.error_outline, color: Colors.red),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               _error!,
//                               style: TextStyle(color: Colors.red),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   SizedBox(height: 24),
                  
//                   // Total price
//                   Container(
//                     padding: EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[100],
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Total Price:',
//                           style: TextStyle(
//                             fontSize: 18,
//                           ),
//                         ),
//                         Text(
//                           '${AppConfig.currencySymbol}${_totalCost.toStringAsFixed(2)}',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Theme.of(context).primaryColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   SizedBox(height: 24),
                  
//                   // Book button
//                   ElevatedButton(
//                     onPressed: widget.parkingSpot.availableSpots > 0 ? _bookParkingSpot : null,
//                     child: Text('BOOK NOW'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 16),
//                       textStyle: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 24),
//                 ],
//               ),
//             ),
//     );
//   }
// }
// lib/models/admin_stats.dart

class AdminStats {
  final int totalUsers;
  final int totalParkingSpots;
  final int totalBookings;
  final double totalRevenue;
  final int activeBookings;
  final int availableParkingSpots;
  final double averageRating;
  final Map<String, int> usersByRole; // role -> count
  final Map<String, int> bookingsByStatus; // status -> count
  final Map<String, int> parkingSpotsByStatus; // status -> count
  final DateTime lastUpdated;

  AdminStats({
    required this.totalUsers,
    required this.totalParkingSpots,
    required this.totalBookings,
    required this.totalRevenue,
    required this.activeBookings,
    required this.availableParkingSpots,
    required this.averageRating,
    this.usersByRole = const {},
    this.bookingsByStatus = const {},
    this.parkingSpotsByStatus = const {},
    required this.lastUpdated,
  });

  // Calculate occupancy rate
  double get occupancyRate {
    if (totalParkingSpots == 0) return 0.0;
    final occupiedSpots = totalParkingSpots - availableParkingSpots;
    return (occupiedSpots / totalParkingSpots) * 100;
  }

  // Calculate booking completion rate
  double get completionRate {
    if (totalBookings == 0) return 0.0;
    final completedBookings = bookingsByStatus['completed'] ?? 0;
    return (completedBookings / totalBookings) * 100;
  }

  // Calculate average revenue per booking
  double get averageRevenuePerBooking {
    if (totalBookings == 0) return 0.0;
    return totalRevenue / totalBookings;
  }
}

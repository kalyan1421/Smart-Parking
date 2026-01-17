// lib/models/admin_stats.dart

class AdminStats {
  final int totalUsers;
  final int totalParkingSpots;
  final int totalBookings;
  final double totalRevenue;
  final double todayRevenue;
  final int todayBookings;
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
    this.todayRevenue = 0.0,
    this.todayBookings = 0,
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

  // Get pending bookings count
  int get pendingBookings => bookingsByStatus['pending'] ?? 0;

  // Get confirmed bookings count
  int get confirmedBookings => bookingsByStatus['confirmed'] ?? 0;

  // Get completed bookings count
  int get completedBookings => bookingsByStatus['completed'] ?? 0;

  // Get cancelled bookings count
  int get cancelledBookings => bookingsByStatus['cancelled'] ?? 0;

  // Get regular users count
  int get regularUsers => usersByRole['user'] ?? 0;

  // Get parking operators count
  int get parkingOperators => usersByRole['parkingOperator'] ?? 0;

  // Get admins count
  int get admins => usersByRole['admin'] ?? 0;

  // Get available parking spots count
  int get availableSpots => parkingSpotsByStatus['available'] ?? 0;

  // Get occupied parking spots count
  int get occupiedSpots => parkingSpotsByStatus['occupied'] ?? 0;

  // Get maintenance parking spots count
  int get maintenanceSpots => parkingSpotsByStatus['maintenance'] ?? 0;

  // Copy with method
  AdminStats copyWith({
    int? totalUsers,
    int? totalParkingSpots,
    int? totalBookings,
    double? totalRevenue,
    double? todayRevenue,
    int? todayBookings,
    int? activeBookings,
    int? availableParkingSpots,
    double? averageRating,
    Map<String, int>? usersByRole,
    Map<String, int>? bookingsByStatus,
    Map<String, int>? parkingSpotsByStatus,
    DateTime? lastUpdated,
  }) {
    return AdminStats(
      totalUsers: totalUsers ?? this.totalUsers,
      totalParkingSpots: totalParkingSpots ?? this.totalParkingSpots,
      totalBookings: totalBookings ?? this.totalBookings,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      todayBookings: todayBookings ?? this.todayBookings,
      activeBookings: activeBookings ?? this.activeBookings,
      availableParkingSpots: availableParkingSpots ?? this.availableParkingSpots,
      averageRating: averageRating ?? this.averageRating,
      usersByRole: usersByRole ?? this.usersByRole,
      bookingsByStatus: bookingsByStatus ?? this.bookingsByStatus,
      parkingSpotsByStatus: parkingSpotsByStatus ?? this.parkingSpotsByStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

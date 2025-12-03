
// lib/core/utils/date_formatter.dart - Date/time utilities
import 'package:intl/intl.dart';

class DateFormatter {
  // Format date to readable string
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  // Format time to readable string
  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
  
  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy - h:mm a').format(dateTime);
  }
  
  // Format duration in hours and minutes
  static String formatDuration(DateTime start, DateTime end) {
    final difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours == 0) {
      return '$minutes min';
    } else if (minutes == 0) {
      return '$hours hr';
    } else {
      return '$hours hr $minutes min';
    }
  }
}

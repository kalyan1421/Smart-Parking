// lib/widgets/custom_marker_generator.dart
// Optimized custom marker generator with efficient caching and resource management

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Custom marker generator that creates info-rich markers showing:
/// - Parking lot name
/// - Live available slots count
/// - Color-coded availability status
/// 
/// Optimized to prevent ImageReader buffer exhaustion
class CustomMarkerGenerator {
  // Cache to avoid regenerating identical markers
  static final Map<String, BitmapDescriptor> _markerCache = {};
  
  // Semaphore to limit concurrent image generation
  static int _activeGenerations = 0;
  static const int _maxConcurrentGenerations = 3;
  static final List<Completer<void>> _waitQueue = [];
  
  // Cache size limit
  static const int _maxCacheSize = 50;
  
  /// Wait for slot to generate image
  static Future<void> _acquireSlot() async {
    if (_activeGenerations < _maxConcurrentGenerations) {
      _activeGenerations++;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
    _activeGenerations++;
  }
  
  /// Release slot after generation
  static void _releaseSlot() {
    _activeGenerations--;
    if (_waitQueue.isNotEmpty && _activeGenerations < _maxConcurrentGenerations) {
      final next = _waitQueue.removeAt(0);
      next.complete();
    }
  }
  
  /// Get availability category for smarter caching
  /// Instead of caching every unique number, cache by category
  static String _getAvailabilityCategory(int available, int total) {
    if (available == 0) return 'full';
    final ratio = available / total;
    if (ratio <= 0.1) return 'critical';
    if (ratio <= 0.25) return 'low';
    if (ratio <= 0.5) return 'medium';
    return 'high';
  }
  
  /// Generate a simple colored marker with just the slot count
  /// Optimized with resource management
  static Future<BitmapDescriptor> generateSlotMarker({
    required int availableSpots,
    required int totalSpots,
    double size = 48,
  }) async {
    // Use category-based caching to reduce unique markers
    final category = _getAvailabilityCategory(availableSpots, totalSpots);
    final displayNumber = availableSpots > 99 ? '99+' : availableSpots.toString();
    final cacheKey = 'slot_${category}_$displayNumber';
    
    // Return cached marker if available
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    // Limit cache size
    if (_markerCache.length >= _maxCacheSize) {
      // Remove oldest entries
      final keysToRemove = _markerCache.keys.take(10).toList();
      for (final key in keysToRemove) {
        _markerCache.remove(key);
      }
    }
    
    // Wait for available slot
    await _acquireSlot();
    
    try {
      // Double-check cache after waiting
      if (_markerCache.containsKey(cacheKey)) {
        return _markerCache[cacheKey]!;
      }
      
      final color = _getAvailabilityColor(availableSpots, totalSpots);
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Draw circle background
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, paint);
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);
      
      // Draw slot count text
      final textPainter = TextPainter(
        text: TextSpan(
          text: displayNumber,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      // Dispose image to free resources
      image.dispose();
      
      if (byteData == null) {
        return BitmapDescriptor.defaultMarker;
      }
      
      final bytes = byteData.buffer.asUint8List();
      final descriptor = BitmapDescriptor.bytes(bytes);
      
      // Cache the result
      _markerCache[cacheKey] = descriptor;
      
      return descriptor;
    } catch (e) {
      // Return default marker on error
      return BitmapDescriptor.defaultMarkerWithHue(
        availableSpots == 0 ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen
      );
    } finally {
      _releaseSlot();
    }
  }
  
  /// Generate a custom marker with parking name and available slots
  static Future<BitmapDescriptor> generateMarker({
    required String name,
    required int availableSpots,
    required int totalSpots,
    double width = 180,
    double height = 80,
  }) async {
    final category = _getAvailabilityCategory(availableSpots, totalSpots);
    final truncatedName = name.length > 10 ? name.substring(0, 10) : name;
    final cacheKey = 'marker_${truncatedName}_${category}_$availableSpots';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    // Limit cache size
    if (_markerCache.length >= _maxCacheSize) {
      final keysToRemove = _markerCache.keys.take(10).toList();
      for (final key in keysToRemove) {
        _markerCache.remove(key);
      }
    }
    
    await _acquireSlot();
    
    try {
      if (_markerCache.containsKey(cacheKey)) {
        return _markerCache[cacheKey]!;
      }
      
      final color = _getAvailabilityColor(availableSpots, totalSpots);
      final textColor = Colors.white;
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      _drawMarkerBackground(canvas, width, height, color);
      _drawMarkerText(canvas, width, height, name, availableSpots, totalSpots, textColor);
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      // Dispose image to free resources
      image.dispose();
      
      if (byteData == null) {
        return BitmapDescriptor.defaultMarker;
      }
      
      final bytes = byteData.buffer.asUint8List();
      final descriptor = BitmapDescriptor.bytes(bytes);
      
      _markerCache[cacheKey] = descriptor;
      
      return descriptor;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(
        availableSpots == 0 ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen
      );
    } finally {
      _releaseSlot();
    }
  }
  
  /// Get color based on availability percentage
  static Color _getAvailabilityColor(int available, int total) {
    if (available == 0) {
      return const Color(0xFFE53935); // Red - Full
    }
    
    if (total == 0) return const Color(0xFF4CAF50);
    
    final percentage = available / total;
    
    if (percentage <= 0.1) {
      return const Color(0xFFFF5722); // Deep Orange - Almost full
    } else if (percentage <= 0.25) {
      return const Color(0xFFFF9800); // Orange - Few spots
    } else if (percentage <= 0.5) {
      return const Color(0xFFFFC107); // Amber - Some spots
    } else {
      return const Color(0xFF4CAF50); // Green - Many spots
    }
  }
  
  static void _drawMarkerBackground(
    Canvas canvas, 
    double width, 
    double height,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Draw shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 4, width - 4, height - 20),
      const Radius.circular(12),
    );
    canvas.drawRRect(shadowRect, shadowPaint);
    
    // Draw main body
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height - 16),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, paint);
    
    // Draw pointer triangle
    final path = Path();
    path.moveTo(width / 2 - 10, height - 16);
    path.lineTo(width / 2, height);
    path.lineTo(width / 2 + 10, height - 16);
    path.close();
    canvas.drawPath(path, paint);
    
    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRRect(rect, borderPaint);
  }
  
  static void _drawMarkerText(
    Canvas canvas,
    double width,
    double height,
    String name,
    int availableSpots,
    int totalSpots,
    Color textColor,
  ) {
    // Truncate name if too long
    final displayName = name.length > 15 ? '${name.substring(0, 12)}...' : name;
    
    // Draw name
    final namePainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    namePainter.layout(maxWidth: width - 16);
    namePainter.paint(
      canvas,
      Offset((width - namePainter.width) / 2, 8),
    );
    
    // Draw availability
    final availText = '$availableSpots / $totalSpots spots';
    final availPainter = TextPainter(
      text: TextSpan(
        text: availText,
        style: TextStyle(
          color: textColor.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    availPainter.layout(maxWidth: width - 16);
    availPainter.paint(
      canvas,
      Offset((width - availPainter.width) / 2, 28),
    );
    
    // Draw status indicator
    final status = availableSpots == 0 ? 'FULL' : 
                   availableSpots <= 2 ? 'FEW LEFT' : 'AVAILABLE';
    
    final statusPainter = TextPainter(
      text: TextSpan(
        text: status,
        style: TextStyle(
          color: textColor.withOpacity(0.8),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    statusPainter.layout(maxWidth: width - 16);
    statusPainter.paint(
      canvas,
      Offset((width - statusPainter.width) / 2, 44),
    );
  }
  
  /// Clear the marker cache (call when memory is low)
  static void clearCache() {
    _markerCache.clear();
  }
  
  /// Get cached marker count (for debugging)
  static int get cacheSize => _markerCache.length;
}

/// Marker data class for efficient updates
class ParkingMarkerData {
  final String id;
  final String name;
  final LatLng position;
  final int availableSpots;
  final int totalSpots;
  final double pricePerHour;
  BitmapDescriptor? cachedIcon;
  
  ParkingMarkerData({
    required this.id,
    required this.name,
    required this.position,
    required this.availableSpots,
    required this.totalSpots,
    required this.pricePerHour,
    this.cachedIcon,
  });
  
  /// Check if marker needs icon update - uses category comparison
  bool needsIconUpdate(ParkingMarkerData other) {
    // Only regenerate if category changed, not exact number
    final oldCategory = _getCategory(availableSpots, totalSpots);
    final newCategory = _getCategory(other.availableSpots, other.totalSpots);
    return oldCategory != newCategory || name != other.name;
  }
  
  String _getCategory(int available, int total) {
    if (available == 0) return 'full';
    if (total == 0) return 'high';
    final ratio = available / total;
    if (ratio <= 0.1) return 'critical';
    if (ratio <= 0.25) return 'low';
    if (ratio <= 0.5) return 'medium';
    return 'high';
  }
  
  /// Check if position changed
  bool positionChanged(ParkingMarkerData other) {
    return position.latitude != other.position.latitude ||
           position.longitude != other.position.longitude;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingMarkerData &&
        other.id == id &&
        other.name == name &&
        other.position == position &&
        other.availableSpots == availableSpots &&
        other.totalSpots == totalSpots;
  }
  
  @override
  int get hashCode {
    return Object.hash(id, name, position, availableSpots, totalSpots);
  }
}

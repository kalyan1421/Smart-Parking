// lib/core/utils/math_extensions.dart - Add this file for math operations
// Add this import at the top of both repository files
import 'dart:math' as dart;
import 'package:smart_parking_app/core/utils/math_extensions.dart';

extension MathExtensions on double {
  double sin() {
    return _sin(this);
  }

  double cos() {
    return _cos(this);
  }

  double sqrt() {
    return _sqrt(this);
  }

  double atan2(double y) {
    return _atan2(this, y);
  }

  // Private implementations
  double _sin(double x) {
    // Simple sine implementation
    return dart.sin(x);
  }

  double _cos(double x) {
    // Simple cosine implementation
    return dart.cos(x);
  }

  double _sqrt(double x) {
    // Simple square root implementation
    return dart.sqrt(x);
  }

  double _atan2(double y, double x) {
    // Simple atan2 implementation
    return dart.atan2(y, x);
  }
}

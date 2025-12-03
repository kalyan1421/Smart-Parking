// lib/utils/id_generator.dart
import 'dart:math';

/// Simple utility to generate unique IDs
class IdGenerator {
  static final Random _random = Random();
  
  /// Generates a random hexadecimal ID
  static String generate() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
        _random.nextInt(10000).toString().padLeft(4, '0');
  }
  
  /// Creates an ObjectId-like object that has a toHexString method
  /// to maintain compatibility with the existing code
  static ObjectIdLike generateObjectId() {
    return ObjectIdLike(generate());
  }
}

/// Simulates MongoDB ObjectId with toHexString method
class ObjectIdLike {
  final String _id;
  
  ObjectIdLike(this._id);
  
  String toHexString() {
    return _id;
  }
  
  @override
  String toString() {
    return _id;
  }
}
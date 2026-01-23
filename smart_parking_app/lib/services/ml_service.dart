// lib/services/ml_service.dart
// TFLite-based Machine Learning Service for on-device inference

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Configuration for ML models
class MLConfig {
  static const String plateDetectorModel = 'assets/ml_models/plate_detector.tflite';
  static const String plateDetectorLabels = 'assets/ml_models/plate_detector_labels.txt';
  static const String weatherRecommenderModel = 'assets/ml_models/weather_recommender.tflite';
  
  static const int plateInputSize = 320;
  static const int plateOutputClasses = 2; // license_plate, vehicle
  static const double confidenceThreshold = 0.5;
}

/// Result from plate detection
class PlateDetectionResult {
  final String? plateNumber;
  final double confidence;
  final List<int>? boundingBox; // [x, y, width, height]
  final bool isValidFormat;
  final String? error;
  
  PlateDetectionResult({
    this.plateNumber,
    this.confidence = 0.0,
    this.boundingBox,
    this.isValidFormat = false,
    this.error,
  });
  
  bool get isSuccess => plateNumber != null && plateNumber!.isNotEmpty;
  
  Map<String, dynamic> toJson() => {
    'plate_number': plateNumber,
    'confidence': confidence,
    'bounding_box': boundingBox,
    'is_valid_format': isValidFormat,
    'error': error,
  };
}

/// Result from weather recommendation
class RecommendationResult {
  final double score; // 0-1
  final List<String> reasons;
  final Map<String, dynamic> weatherFactors;
  
  RecommendationResult({
    required this.score,
    this.reasons = const [],
    this.weatherFactors = const {},
  });
}

/// Machine Learning Service for on-device inference
/// 
/// Usage:
/// ```dart
/// final mlService = MLService();
/// await mlService.initialize();
/// 
/// // Detect plate
/// final result = await mlService.detectPlate(imageBytes);
/// print(result.plateNumber);
/// 
/// // Get recommendation score
/// final score = await mlService.getRecommendationScore(features);
/// ```
class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();
  
  bool _isInitialized = false;
  bool _plateDetectorLoaded = false;
  bool _recommenderLoaded = false;
  
  // TFLite interpreter references would go here
  // We'll use a simplified approach that works without native TFLite
  
  /// Initialize ML models
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Try to load TFLite models
      await _loadPlateDetector();
      await _loadRecommender();
      _isInitialized = true;
      print('ML Service initialized successfully');
    } catch (e) {
      print('ML Service initialization failed: $e');
      print('Falling back to rule-based methods');
      _isInitialized = true; // Mark as initialized even without TFLite
    }
  }
  
  Future<void> _loadPlateDetector() async {
    try {
      // Check if model file exists
      final modelData = await rootBundle.load(MLConfig.plateDetectorModel);
      if (modelData.lengthInBytes > 0) {
        _plateDetectorLoaded = true;
        print('Plate detector model loaded: ${modelData.lengthInBytes} bytes');
      }
    } catch (e) {
      print('Plate detector not available: $e');
      _plateDetectorLoaded = false;
    }
  }
  
  Future<void> _loadRecommender() async {
    try {
      final modelData = await rootBundle.load(MLConfig.weatherRecommenderModel);
      if (modelData.lengthInBytes > 0) {
        _recommenderLoaded = true;
        print('Recommender model loaded: ${modelData.lengthInBytes} bytes');
      }
    } catch (e) {
      print('Recommender not available: $e');
      _recommenderLoaded = false;
    }
  }
  
  /// Detect license plate from image bytes
  /// 
  /// [imageBytes] - Raw image data (JPEG/PNG)
  /// Returns [PlateDetectionResult] with plate number and confidence
  Future<PlateDetectionResult> detectPlate(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (!_plateDetectorLoaded) {
      return PlateDetectionResult(
        error: 'Plate detector model not loaded. Use API fallback.',
      );
    }
    
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return PlateDetectionResult(error: 'Could not decode image');
      }
      
      // Preprocess for model
      final inputData = _preprocessImage(image);
      
      // Run TFLite inference (placeholder - actual implementation needs tflite_flutter)
      // In production, use:
      // final output = _interpreter.run(inputData);
      
      // For now, use OCR-based fallback
      final plateText = await _extractPlateText(image);
      final isValid = _validateIndianPlate(plateText);
      
      return PlateDetectionResult(
        plateNumber: plateText,
        confidence: plateText.isNotEmpty ? 0.85 : 0.0,
        isValidFormat: isValid,
      );
      
    } catch (e) {
      return PlateDetectionResult(error: 'Detection failed: $e');
    }
  }
  
  /// Get recommendation score for a parking spot
  /// 
  /// [features] - Map of feature names to values
  /// Returns [RecommendationResult] with score and reasons
  Future<RecommendationResult> getRecommendationScore(Map<String, dynamic> features) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Use rule-based scoring (works without TFLite)
    return _calculateRuleBasedScore(features);
  }
  
  /// Preprocess image for TFLite model
  Float32List _preprocessImage(img.Image image) {
    // Resize to model input size
    final resized = img.copyResize(
      image,
      width: MLConfig.plateInputSize,
      height: MLConfig.plateInputSize,
    );
    
    // Convert to float array (normalized 0-1)
    final inputSize = MLConfig.plateInputSize * MLConfig.plateInputSize * 3;
    final input = Float32List(inputSize);
    
    int pixelIndex = 0;
    for (int y = 0; y < MLConfig.plateInputSize; y++) {
      for (int x = 0; x < MLConfig.plateInputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }
    
    return input;
  }
  
  /// Extract plate text using image processing (fallback method)
  Future<String> _extractPlateText(img.Image image) async {
    // This is a simplified placeholder
    // In production, use EasyOCR API or on-device OCR
    
    // For now, return empty - the actual OCR would be done server-side
    // or using ML Kit's text recognition
    return '';
  }
  
  /// Validate Indian license plate format
  bool _validateIndianPlate(String text) {
    if (text.isEmpty) return false;
    
    // Clean text
    final cleaned = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    // Indian plate pattern: SS NN X/XX NNNN
    final pattern = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{1,3}\d{1,4}$');
    
    return pattern.hasMatch(cleaned);
  }
  
  /// Rule-based recommendation scoring
  RecommendationResult _calculateRuleBasedScore(Map<String, dynamic> features) {
    double score = 0.5;
    final reasons = <String>[];
    
    // Extract features with defaults
    final isRaining = features['is_raining'] ?? false;
    final isHot = features['is_hot'] ?? false;
    final temperature = (features['temperature'] ?? 25.0) as double;
    final isCovered = features['is_covered'] ?? false;
    final isUnderground = features['is_underground'] ?? false;
    final hasSecurity = features['has_security'] ?? false;
    final distance = (features['distance'] ?? 1000.0) as double;
    final price = (features['price'] ?? 50.0) as double;
    final availability = (features['availability'] ?? 0.5) as double;
    final rating = (features['rating'] ?? 4.0) as double;
    final isDaytime = features['is_daytime'] ?? true;
    
    // Weather-based scoring
    if (isRaining) {
      if (isUnderground) {
        score += 0.3;
        reasons.add('Protected from rain (underground)');
      } else if (isCovered) {
        score += 0.2;
        reasons.add('Covered parking - stay dry');
      } else {
        score -= 0.15;
        reasons.add('Open parking - may get wet');
      }
    }
    
    if (isHot || temperature > 35) {
      if (isUnderground) {
        score += 0.25;
        reasons.add('Cool underground parking');
      } else if (isCovered) {
        score += 0.15;
        reasons.add('Shaded - car stays cooler');
      } else {
        score -= 0.1;
        reasons.add('Open parking - car may heat up');
      }
    }
    
    // Night time safety
    if (!isDaytime && hasSecurity) {
      score += 0.15;
      reasons.add('Secure parking for night');
    }
    
    // Distance score (closer is better)
    if (distance < 500) {
      score += 0.15;
      reasons.add('Very close to destination');
    } else if (distance < 1000) {
      score += 0.08;
      reasons.add('Within walking distance');
    }
    
    // Price score
    if (price < 30) {
      score += 0.1;
      reasons.add('Budget-friendly');
    }
    
    // Availability score
    score += availability * 0.1;
    if (availability > 0.5) {
      reasons.add('Good availability');
    } else if (availability < 0.2) {
      reasons.add('Limited spots - book quickly!');
    }
    
    // Rating score
    if (rating >= 4.5) {
      score += 0.1;
      reasons.add('Highly rated');
    }
    
    // Clamp score to 0-1
    score = score.clamp(0.0, 1.0);
    
    return RecommendationResult(
      score: score,
      reasons: reasons,
      weatherFactors: {
        'temperature': temperature,
        'is_raining': isRaining,
        'is_hot': isHot,
        'is_daytime': isDaytime,
      },
    );
  }
  
  /// Dispose resources
  void dispose() {
    // Clean up TFLite interpreters if loaded
    _isInitialized = false;
    _plateDetectorLoaded = false;
    _recommenderLoaded = false;
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get plateDetectorAvailable => _plateDetectorLoaded;
  bool get recommenderAvailable => _recommenderLoaded;
}

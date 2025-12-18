import 'package:dio/dio.dart';

class WeatherService {
  final Dio _dio = Dio();
  // using the key provided in your request
  final String _apiKey = '20086885603c43a4a7c42512252503';
  final String _baseUrl = 'http://api.weatherapi.com/v1/current.json';

  Future<WeatherData?> getCurrentWeather(double lat, double lon) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'key': _apiKey,
        'q': '$lat,$lon', // Dynamic location based on user coordinates
        'aqi': 'no',
      });

      if (response.statusCode == 200) {
        return WeatherData.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }
}

class WeatherData {
  final double tempC;
  final String conditionText;
  final String iconUrl;
  final int conditionCode;

  WeatherData({
    required this.tempC,
    required this.conditionText,
    required this.iconUrl,
    required this.conditionCode,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final condition = current['condition'];
    
    return WeatherData(
      tempC: (current['temp_c'] as num).toDouble(),
      conditionText: condition['text'],
      iconUrl: 'https:${condition['icon']}',
      conditionCode: condition['code'],
    );
  }

  // Check for adverse weather conditions based on text or temperature
  bool get isRaining => 
      conditionText.toLowerCase().contains('rain') || 
      conditionText.toLowerCase().contains('drizzle') ||
      conditionText.toLowerCase().contains('shower') ||
      conditionText.toLowerCase().contains('thunder');

  bool get isSnowing => 
      conditionText.toLowerCase().contains('snow') || 
      conditionText.toLowerCase().contains('blizzard') ||
      conditionText.toLowerCase().contains('sleet') || 
      conditionText.toLowerCase().contains('ice');

  bool get isHot => tempC > 35.0; // Suggest covered parking if > 35°C
}
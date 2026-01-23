"""
Weather API Service
Fetches real-time weather data for parking recommendations
"""

import os
import requests
from typing import Dict, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


@dataclass
class WeatherData:
    """Weather data structure"""
    temperature: float  # Celsius
    feels_like: float
    humidity: int  # Percentage
    pressure: int  # hPa
    wind_speed: float  # m/s
    wind_direction: int  # degrees
    visibility: int  # meters
    clouds: int  # Percentage
    weather_main: str  # Main condition (Rain, Clear, Clouds, etc.)
    weather_description: str
    weather_icon: str
    sunrise: datetime
    sunset: datetime
    is_raining: bool
    rain_intensity: float  # mm/h
    uv_index: Optional[float] = None
    
    @property
    def is_hot(self) -> bool:
        return self.temperature > 35
    
    @property
    def is_cold(self) -> bool:
        return self.temperature < 15
    
    @property
    def is_daytime(self) -> bool:
        now = datetime.now()
        return self.sunrise <= now <= self.sunset
    
    @property
    def is_poor_visibility(self) -> bool:
        return self.visibility < 1000
    
    @property
    def is_windy(self) -> bool:
        return self.wind_speed > 10
    
    def to_dict(self) -> Dict:
        return {
            'temperature': self.temperature,
            'feels_like': self.feels_like,
            'humidity': self.humidity,
            'pressure': self.pressure,
            'wind_speed': self.wind_speed,
            'wind_direction': self.wind_direction,
            'visibility': self.visibility,
            'clouds': self.clouds,
            'weather_main': self.weather_main,
            'weather_description': self.weather_description,
            'is_raining': self.is_raining,
            'rain_intensity': self.rain_intensity,
            'is_hot': self.is_hot,
            'is_cold': self.is_cold,
            'is_daytime': self.is_daytime,
            'uv_index': self.uv_index
        }


class WeatherService:
    """
    Weather service using OpenWeatherMap API
    """
    
    BASE_URL = "https://api.openweathermap.org/data/2.5"
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize weather service
        
        Args:
            api_key: OpenWeatherMap API key (or set WEATHER_API_KEY env var)
        """
        self.api_key = api_key or os.getenv('WEATHER_API_KEY')
        self._cache = {}
        self._cache_duration = timedelta(minutes=10)
    
    def get_current_weather(self, latitude: float, longitude: float) -> Optional[WeatherData]:
        """
        Get current weather for location
        
        Args:
            latitude: Location latitude
            longitude: Location longitude
            
        Returns:
            WeatherData object or None if failed
        """
        # Check cache
        cache_key = f"{latitude:.2f},{longitude:.2f}"
        cached = self._get_from_cache(cache_key)
        if cached:
            return cached
        
        if not self.api_key:
            print("Warning: No weather API key configured")
            return self._get_default_weather()
        
        try:
            url = f"{self.BASE_URL}/weather"
            params = {
                'lat': latitude,
                'lon': longitude,
                'appid': self.api_key,
                'units': 'metric'
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            weather = self._parse_weather_response(data)
            
            # Cache the result
            self._cache[cache_key] = {
                'data': weather,
                'timestamp': datetime.now()
            }
            
            return weather
            
        except requests.RequestException as e:
            print(f"Weather API error: {e}")
            return self._get_default_weather()
        except Exception as e:
            print(f"Weather parsing error: {e}")
            return self._get_default_weather()
    
    def get_forecast(self, latitude: float, longitude: float, 
                     hours: int = 6) -> list:
        """
        Get weather forecast for next N hours
        
        Args:
            latitude: Location latitude
            longitude: Location longitude
            hours: Number of hours to forecast
            
        Returns:
            List of WeatherData objects
        """
        if not self.api_key:
            return []
        
        try:
            url = f"{self.BASE_URL}/forecast"
            params = {
                'lat': latitude,
                'lon': longitude,
                'appid': self.api_key,
                'units': 'metric',
                'cnt': (hours // 3) + 1  # API returns 3-hour intervals
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            forecasts = []
            
            for item in data.get('list', []):
                weather = self._parse_forecast_item(item, data.get('city', {}))
                if weather:
                    forecasts.append(weather)
            
            return forecasts
            
        except Exception as e:
            print(f"Forecast API error: {e}")
            return []
    
    def _parse_weather_response(self, data: Dict) -> WeatherData:
        """Parse OpenWeatherMap API response"""
        main = data.get('main', {})
        wind = data.get('wind', {})
        weather = data.get('weather', [{}])[0]
        rain = data.get('rain', {})
        sys = data.get('sys', {})
        
        # Parse sunrise/sunset
        sunrise = datetime.fromtimestamp(sys.get('sunrise', 0))
        sunset = datetime.fromtimestamp(sys.get('sunset', 0))
        
        # Check if raining
        is_raining = weather.get('main', '').lower() in ['rain', 'drizzle', 'thunderstorm']
        rain_intensity = rain.get('1h', 0)  # Rain in last hour (mm)
        
        return WeatherData(
            temperature=main.get('temp', 25),
            feels_like=main.get('feels_like', 25),
            humidity=main.get('humidity', 50),
            pressure=main.get('pressure', 1013),
            wind_speed=wind.get('speed', 0),
            wind_direction=wind.get('deg', 0),
            visibility=data.get('visibility', 10000),
            clouds=data.get('clouds', {}).get('all', 0),
            weather_main=weather.get('main', 'Clear'),
            weather_description=weather.get('description', 'clear sky'),
            weather_icon=weather.get('icon', '01d'),
            sunrise=sunrise,
            sunset=sunset,
            is_raining=is_raining,
            rain_intensity=rain_intensity
        )
    
    def _parse_forecast_item(self, item: Dict, city: Dict) -> Optional[WeatherData]:
        """Parse forecast list item"""
        try:
            main = item.get('main', {})
            wind = item.get('wind', {})
            weather = item.get('weather', [{}])[0]
            rain = item.get('rain', {})
            
            sunrise = datetime.fromtimestamp(city.get('sunrise', 0))
            sunset = datetime.fromtimestamp(city.get('sunset', 0))
            
            is_raining = weather.get('main', '').lower() in ['rain', 'drizzle', 'thunderstorm']
            
            return WeatherData(
                temperature=main.get('temp', 25),
                feels_like=main.get('feels_like', 25),
                humidity=main.get('humidity', 50),
                pressure=main.get('pressure', 1013),
                wind_speed=wind.get('speed', 0),
                wind_direction=wind.get('deg', 0),
                visibility=item.get('visibility', 10000),
                clouds=item.get('clouds', {}).get('all', 0),
                weather_main=weather.get('main', 'Clear'),
                weather_description=weather.get('description', 'clear sky'),
                weather_icon=weather.get('icon', '01d'),
                sunrise=sunrise,
                sunset=sunset,
                is_raining=is_raining,
                rain_intensity=rain.get('3h', 0) / 3  # Convert 3h to 1h
            )
        except Exception:
            return None
    
    def _get_from_cache(self, key: str) -> Optional[WeatherData]:
        """Get cached weather data if not expired"""
        if key in self._cache:
            cached = self._cache[key]
            if datetime.now() - cached['timestamp'] < self._cache_duration:
                return cached['data']
        return None
    
    def _get_default_weather(self) -> WeatherData:
        """Return default weather data when API is unavailable"""
        now = datetime.now()
        return WeatherData(
            temperature=28,
            feels_like=30,
            humidity=60,
            pressure=1013,
            wind_speed=5,
            wind_direction=180,
            visibility=10000,
            clouds=30,
            weather_main='Clear',
            weather_description='clear sky',
            weather_icon='01d',
            sunrise=now.replace(hour=6, minute=0),
            sunset=now.replace(hour=18, minute=30),
            is_raining=False,
            rain_intensity=0
        )


# Test
if __name__ == '__main__':
    service = WeatherService()
    
    # Test with Hyderabad coordinates
    weather = service.get_current_weather(17.385, 78.486)
    
    if weather:
        print(f"Temperature: {weather.temperature}°C")
        print(f"Condition: {weather.weather_description}")
        print(f"Raining: {weather.is_raining}")
        print(f"Hot: {weather.is_hot}")

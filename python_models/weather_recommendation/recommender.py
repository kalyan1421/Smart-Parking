"""
Weather-based Parking Recommendation Engine
Suggests optimal parking spots based on weather conditions and user preferences
"""

import os
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime
import math

try:
    import numpy as np
    from sklearn.ensemble import RandomForestClassifier
    import joblib
    ML_AVAILABLE = True
except ImportError:
    ML_AVAILABLE = False

from .weather_api import WeatherService, WeatherData


@dataclass
class ParkingSpot:
    """Parking spot data structure"""
    id: str
    name: str
    latitude: float
    longitude: float
    total_spots: int
    available_spots: int
    price_per_hour: float
    is_covered: bool  # Has roof/shade
    is_underground: bool
    has_ev_charging: bool
    has_security: bool
    distance_to_user: float  # meters
    rating: float
    amenities: List[str]
    
    @property
    def occupancy_rate(self) -> float:
        if self.total_spots == 0:
            return 1.0
        return 1 - (self.available_spots / self.total_spots)
    
    @property
    def is_available(self) -> bool:
        return self.available_spots > 0


@dataclass
class Recommendation:
    """Recommendation result"""
    spot: ParkingSpot
    score: float
    reasons: List[str]
    weather_factors: Dict
    
    def to_dict(self) -> Dict:
        return {
            'spot_id': self.spot.id,
            'spot_name': self.spot.name,
            'score': self.score,
            'reasons': self.reasons,
            'weather_factors': self.weather_factors,
            'available_spots': self.spot.available_spots,
            'price_per_hour': self.spot.price_per_hour,
            'distance': self.spot.distance_to_user,
            'is_covered': self.spot.is_covered,
            'is_underground': self.spot.is_underground
        }


class ParkingRecommender:
    """
    ML-powered parking recommendation engine
    Considers weather, distance, price, availability, and spot features
    """
    
    def __init__(self, model_path: Optional[str] = None):
        """
        Initialize recommender
        
        Args:
            model_path: Path to trained ML model (optional)
        """
        self.weather_service = WeatherService()
        self.model = None
        self.model_path = model_path or os.path.join(
            os.path.dirname(__file__), '..', 'models', 'recommender_model.pkl'
        )
        
        # Weights for rule-based scoring
        self.weights = {
            'distance': 0.25,
            'price': 0.15,
            'availability': 0.20,
            'weather_suitability': 0.25,
            'rating': 0.10,
            'amenities': 0.05
        }
        
        self._load_model()
    
    def _load_model(self):
        """Load trained ML model if available"""
        if not ML_AVAILABLE:
            return
        
        try:
            if os.path.exists(self.model_path):
                self.model = joblib.load(self.model_path)
                print(f"Loaded recommendation model from {self.model_path}")
        except Exception as e:
            print(f"Could not load model: {e}")
            self.model = None
    
    def get_recommendations(
        self,
        latitude: float,
        longitude: float,
        parking_spots: List[Dict],
        max_results: int = 10,
        max_distance: float = 5000,  # meters
        preferences: Optional[Dict] = None
    ) -> List[Recommendation]:
        """
        Get parking recommendations based on location and weather
        
        Args:
            latitude: User's latitude
            longitude: User's longitude
            parking_spots: List of available parking spots from database
            max_results: Maximum recommendations to return
            max_distance: Maximum distance in meters
            preferences: User preferences (prefer_covered, max_price, etc.)
            
        Returns:
            List of Recommendation objects sorted by score
        """
        # Get current weather
        weather = self.weather_service.get_current_weather(latitude, longitude)
        
        if not weather:
            weather = self.weather_service._get_default_weather()
        
        # Parse preferences
        prefs = preferences or {}
        prefer_covered = prefs.get('prefer_covered', weather.is_raining or weather.is_hot)
        max_price = prefs.get('max_price', float('inf'))
        prefer_underground = prefs.get('prefer_underground', weather.is_hot)
        needs_ev_charging = prefs.get('needs_ev_charging', False)
        
        recommendations = []
        
        for spot_data in parking_spots:
            # Create ParkingSpot object
            spot = self._parse_parking_spot(spot_data, latitude, longitude)
            
            # Filter by distance
            if spot.distance_to_user > max_distance:
                continue
            
            # Filter by availability
            if not spot.is_available:
                continue
            
            # Filter by price
            if spot.price_per_hour > max_price:
                continue
            
            # Filter by EV charging if needed
            if needs_ev_charging and not spot.has_ev_charging:
                continue
            
            # Calculate recommendation score
            score, reasons, weather_factors = self._calculate_score(
                spot, weather, prefer_covered, prefer_underground
            )
            
            recommendations.append(Recommendation(
                spot=spot,
                score=score,
                reasons=reasons,
                weather_factors=weather_factors
            ))
        
        # Sort by score (descending)
        recommendations.sort(key=lambda r: r.score, reverse=True)
        
        return recommendations[:max_results]
    
    def _parse_parking_spot(self, data: Dict, user_lat: float, 
                            user_lon: float) -> ParkingSpot:
        """Parse parking spot from dictionary"""
        spot_lat = data.get('latitude', 0)
        spot_lon = data.get('longitude', 0)
        
        # Calculate distance
        distance = self._haversine_distance(user_lat, user_lon, spot_lat, spot_lon)
        
        # Parse amenities to determine features
        amenities = data.get('amenities', [])
        is_covered = any(a.lower() in ['covered', 'roof', 'shade', 'indoor'] 
                        for a in amenities)
        is_underground = any(a.lower() in ['underground', 'basement', 'basement parking'] 
                            for a in amenities)
        has_ev = any(a.lower() in ['ev charging', 'electric vehicle', 'ev'] 
                    for a in amenities)
        has_security = any(a.lower() in ['security', 'cctv', 'guard', '24/7'] 
                          for a in amenities)
        
        return ParkingSpot(
            id=data.get('id', ''),
            name=data.get('name', 'Unknown'),
            latitude=spot_lat,
            longitude=spot_lon,
            total_spots=data.get('totalSpots', 0),
            available_spots=data.get('availableSpots', 0),
            price_per_hour=data.get('pricePerHour', 0),
            is_covered=is_covered or data.get('isCovered', False),
            is_underground=is_underground or data.get('isUnderground', False),
            has_ev_charging=has_ev or data.get('hasEvCharging', False),
            has_security=has_security or data.get('hasSecurity', False),
            distance_to_user=distance,
            rating=data.get('rating', 0),
            amenities=amenities
        )
    
    def _calculate_score(
        self,
        spot: ParkingSpot,
        weather: WeatherData,
        prefer_covered: bool,
        prefer_underground: bool
    ) -> tuple:
        """
        Calculate recommendation score for a parking spot
        
        Returns:
            Tuple of (score, reasons, weather_factors)
        """
        scores = {}
        reasons = []
        weather_factors = weather.to_dict()
        
        # Distance score (closer is better, normalized to 0-1)
        max_dist = 5000  # 5km max
        scores['distance'] = max(0, 1 - (spot.distance_to_user / max_dist))
        if spot.distance_to_user < 500:
            reasons.append("Very close to your location")
        elif spot.distance_to_user < 1000:
            reasons.append("Within walking distance")
        
        # Price score (cheaper is better, assuming max reasonable price is 100/hr)
        max_price = 100
        scores['price'] = max(0, 1 - (spot.price_per_hour / max_price))
        if spot.price_per_hour < 30:
            reasons.append("Budget-friendly pricing")
        
        # Availability score
        scores['availability'] = 1 - spot.occupancy_rate
        if spot.available_spots > 10:
            reasons.append("Plenty of spots available")
        elif spot.available_spots <= 3:
            reasons.append("Limited spots - book quickly!")
        
        # Weather suitability score
        weather_score = self._calculate_weather_suitability(
            spot, weather, prefer_covered, prefer_underground
        )
        scores['weather_suitability'] = weather_score['score']
        reasons.extend(weather_score['reasons'])
        
        # Rating score
        scores['rating'] = spot.rating / 5.0 if spot.rating else 0.5
        if spot.rating >= 4.5:
            reasons.append("Highly rated by users")
        
        # Amenities score
        amenity_score = len(spot.amenities) / 10  # Assume max 10 amenities
        scores['amenities'] = min(1, amenity_score)
        
        # Calculate weighted final score
        final_score = sum(
            scores[key] * self.weights[key] 
            for key in self.weights
        )
        
        # Bonus for perfect weather match
        if scores['weather_suitability'] > 0.9:
            final_score *= 1.1
        
        return (min(1, final_score), reasons, weather_factors)
    
    def _calculate_weather_suitability(
        self,
        spot: ParkingSpot,
        weather: WeatherData,
        prefer_covered: bool,
        prefer_underground: bool
    ) -> Dict:
        """Calculate how suitable a spot is given weather conditions"""
        score = 0.5  # Base score
        reasons = []
        
        # Rainy weather - prefer covered/underground
        if weather.is_raining:
            if spot.is_underground:
                score += 0.4
                reasons.append("Protected from rain (underground)")
            elif spot.is_covered:
                score += 0.3
                reasons.append("Covered parking - stay dry")
            else:
                score -= 0.2
                reasons.append("Open parking - may get wet")
        
        # Hot weather - prefer shade/underground
        if weather.is_hot:
            if spot.is_underground:
                score += 0.4
                reasons.append("Cool underground parking")
            elif spot.is_covered:
                score += 0.25
                reasons.append("Shaded parking - car stays cool")
            else:
                score -= 0.15
                reasons.append("Open parking - car may heat up")
        
        # Cold weather - underground is warmer
        if weather.is_cold:
            if spot.is_underground:
                score += 0.2
                reasons.append("Underground - protected from cold")
        
        # High UV - prefer covered
        if weather.uv_index and weather.uv_index > 6:
            if spot.is_covered or spot.is_underground:
                score += 0.2
                reasons.append("Protected from UV rays")
        
        # Poor visibility (fog) - prefer well-lit/secure
        if weather.is_poor_visibility:
            if spot.has_security:
                score += 0.15
                reasons.append("Secure parking with visibility")
        
        # Night time - prefer secure parking
        if not weather.is_daytime:
            if spot.has_security:
                score += 0.2
                reasons.append("Secure parking for nighttime")
        
        # User preference overrides
        if prefer_covered and not spot.is_covered and not spot.is_underground:
            score -= 0.1
        
        if prefer_underground and spot.is_underground:
            score += 0.15
        
        return {
            'score': max(0, min(1, score)),
            'reasons': reasons
        }
    
    def _haversine_distance(self, lat1: float, lon1: float, 
                            lat2: float, lon2: float) -> float:
        """
        Calculate distance between two coordinates in meters
        """
        R = 6371000  # Earth radius in meters
        
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_phi / 2) ** 2 + 
             math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    def train_model(self, training_data: List[Dict]):
        """
        Train recommendation model on historical data
        
        Args:
            training_data: List of historical booking data with user choices
        """
        if not ML_AVAILABLE:
            print("ML libraries not available for training")
            return
        
        # Feature extraction and model training would go here
        # For now, using rule-based scoring
        print("Model training not yet implemented - using rule-based scoring")
    
    def get_weather_summary(self, latitude: float, longitude: float) -> Dict:
        """
        Get weather summary for display in app
        """
        weather = self.weather_service.get_current_weather(latitude, longitude)
        
        if not weather:
            return {'error': 'Weather data unavailable'}
        
        # Generate parking advice based on weather
        advice = []
        
        if weather.is_raining:
            advice.append("It's raining! We recommend covered parking.")
        elif weather.is_hot:
            advice.append(f"It's {weather.temperature}°C. Underground parking will keep your car cool.")
        elif weather.is_cold:
            advice.append(f"It's {weather.temperature}°C. Consider underground parking for warmth.")
        
        if not weather.is_daytime:
            advice.append("It's nighttime. Prefer parking spots with security.")
        
        return {
            'temperature': weather.temperature,
            'condition': weather.weather_description,
            'icon': weather.weather_icon,
            'is_raining': weather.is_raining,
            'is_hot': weather.is_hot,
            'advice': advice,
            'prefer_covered': weather.is_raining or weather.is_hot,
            'prefer_underground': weather.is_hot
        }


# Test
if __name__ == '__main__':
    recommender = ParkingRecommender()
    
    # Test with sample data
    sample_spots = [
        {
            'id': '1',
            'name': 'City Center Parking',
            'latitude': 17.386,
            'longitude': 78.487,
            'totalSpots': 100,
            'availableSpots': 45,
            'pricePerHour': 40,
            'amenities': ['Covered', 'CCTV', '24/7'],
            'rating': 4.5
        },
        {
            'id': '2',
            'name': 'Mall Underground Parking',
            'latitude': 17.384,
            'longitude': 78.488,
            'totalSpots': 500,
            'availableSpots': 200,
            'pricePerHour': 60,
            'amenities': ['Underground', 'EV Charging', 'Security'],
            'rating': 4.8
        }
    ]
    
    recommendations = recommender.get_recommendations(
        latitude=17.385,
        longitude=78.486,
        parking_spots=sample_spots
    )
    
    print("Recommendations:")
    for rec in recommendations:
        print(f"- {rec.spot.name}: Score {rec.score:.2f}")
        print(f"  Reasons: {', '.join(rec.reasons)}")

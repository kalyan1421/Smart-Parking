"""
Smart Parking API Server
Provides endpoints for number plate recognition and weather-based recommendations
"""

import os
import base64
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np

# Import our modules
from number_plate_recognition import PlateDetector
from weather_recommendation import ParkingRecommender, WeatherService

# Firebase Admin (for booking verification)
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("Firebase Admin SDK not available")

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Initialize services
plate_detector = PlateDetector()
parking_recommender = ParkingRecommender()
weather_service = WeatherService()

# Firebase initialization
db = None
if FIREBASE_AVAILABLE:
    try:
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print("Firebase initialized successfully")
    except Exception as e:
        print(f"Firebase initialization failed: {e}")


# ============================================================================
# NUMBER PLATE RECOGNITION ENDPOINTS
# ============================================================================

@app.route('/api/detect-plate', methods=['POST'])
def detect_plate():
    """
    Detect license plate from image
    
    Accepts:
    - Base64 encoded image in JSON body
    - Multipart form with image file
    
    Returns:
    - plate_number: Detected plate text
    - confidence: Detection confidence (0-1)
    - is_valid_format: Whether plate matches Indian format
    """
    try:
        # Get image from request
        if 'image' in request.files:
            # File upload
            file = request.files['image']
            nparr = np.frombuffer(file.read(), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        elif request.json and 'image' in request.json:
            # Base64 encoded
            image_data = request.json['image']
            # Remove data URL prefix if present
            if ',' in image_data:
                image_data = image_data.split(',')[1]
            nparr = np.frombuffer(base64.b64decode(image_data), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        else:
            return jsonify({'error': 'No image provided'}), 400
        
        if image is None:
            return jsonify({'error': 'Could not decode image'}), 400
        
        # Detect plate
        result = plate_detector.detect_plate(image)
        
        return jsonify({
            'success': True,
            'plate_number': result.get('plate_number'),
            'confidence': result.get('confidence', 0),
            'is_valid_format': result.get('is_valid_format', False),
            'raw_text': result.get('raw_text'),
            'error': result.get('error')
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/check-in', methods=['POST'])
def check_in_vehicle():
    """
    Check-in vehicle by number plate
    
    Flow:
    1. Detect plate from image
    2. Find matching confirmed booking in database
    3. Update booking status to 'active' with check-in time
    
    Request body:
    - image: Base64 encoded image or file upload
    - parking_spot_id: ID of the parking spot (optional for verification)
    """
    try:
        # Get image
        if 'image' in request.files:
            file = request.files['image']
            nparr = np.frombuffer(file.read(), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        elif request.json and 'image' in request.json:
            image_data = request.json['image']
            if ',' in image_data:
                image_data = image_data.split(',')[1]
            nparr = np.frombuffer(base64.b64decode(image_data), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        else:
            return jsonify({'error': 'No image provided'}), 400
        
        parking_spot_id = request.form.get('parking_spot_id') or \
                          (request.json or {}).get('parking_spot_id')
        
        # Detect plate
        result = plate_detector.detect_plate(image)
        plate_number = result.get('plate_number')
        
        if not plate_number:
            return jsonify({
                'success': False,
                'error': 'Could not detect license plate',
                'detection_result': result
            }), 400
        
        # Find matching booking in Firebase
        if not db:
            return jsonify({
                'success': False,
                'error': 'Database not available',
                'plate_number': plate_number
            }), 503
        
        # Query for confirmed bookings with matching plate
        now = datetime.now()
        query = db.collection('bookings').where(
            'vehicleNumberPlate', '==', plate_number.upper()
        ).where(
            'status', 'in', ['confirmed', 'pending']
        )
        
        if parking_spot_id:
            query = query.where('parkingSpotId', '==', parking_spot_id)
        
        bookings = list(query.stream())
        
        if not bookings:
            return jsonify({
                'success': False,
                'error': 'No matching booking found',
                'plate_number': plate_number
            }), 404
        
        # Find the booking that's valid for current time
        matching_booking = None
        for booking_doc in bookings:
            booking = booking_doc.to_dict()
            start_time = booking.get('startTime')
            end_time = booking.get('endTime')
            
            if start_time and end_time:
                start_dt = start_time.timestamp() if hasattr(start_time, 'timestamp') else start_time
                end_dt = end_time.timestamp() if hasattr(end_time, 'timestamp') else end_time
                
                # Allow check-in 15 minutes before start time
                if start_dt - 900 <= now.timestamp() <= end_dt:
                    matching_booking = (booking_doc.id, booking)
                    break
        
        if not matching_booking:
            return jsonify({
                'success': False,
                'error': 'No valid booking for current time',
                'plate_number': plate_number
            }), 404
        
        booking_id, booking_data = matching_booking
        
        # Update booking status to active
        db.collection('bookings').document(booking_id).update({
            'status': 'active',
            'checkedInAt': firestore.SERVER_TIMESTAMP,
            'checkInMethod': 'numberPlate',
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({
            'success': True,
            'message': 'Check-in successful',
            'plate_number': plate_number,
            'booking_id': booking_id,
            'parking_spot': booking_data.get('parkingSpotName'),
            'end_time': booking_data.get('endTime').isoformat() if booking_data.get('endTime') else None
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/check-out', methods=['POST'])
def check_out_vehicle():
    """
    Check-out vehicle by number plate
    
    Flow:
    1. Detect plate from image
    2. Find matching active booking
    3. Update booking status to 'completed' with check-out time
    4. Calculate any overtime fees
    """
    try:
        # Get image
        if 'image' in request.files:
            file = request.files['image']
            nparr = np.frombuffer(file.read(), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        elif request.json and 'image' in request.json:
            image_data = request.json['image']
            if ',' in image_data:
                image_data = image_data.split(',')[1]
            nparr = np.frombuffer(base64.b64decode(image_data), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        else:
            return jsonify({'error': 'No image provided'}), 400
        
        # Detect plate
        result = plate_detector.detect_plate(image)
        plate_number = result.get('plate_number')
        
        if not plate_number:
            return jsonify({
                'success': False,
                'error': 'Could not detect license plate'
            }), 400
        
        if not db:
            return jsonify({
                'success': False,
                'error': 'Database not available',
                'plate_number': plate_number
            }), 503
        
        # Find active booking with matching plate
        query = db.collection('bookings').where(
            'vehicleNumberPlate', '==', plate_number.upper()
        ).where(
            'status', '==', 'active'
        )
        
        bookings = list(query.stream())
        
        if not bookings:
            return jsonify({
                'success': False,
                'error': 'No active booking found for this vehicle',
                'plate_number': plate_number
            }), 404
        
        # Take the first active booking
        booking_doc = bookings[0]
        booking_id = booking_doc.id
        booking_data = booking_doc.to_dict()
        
        # Calculate overtime fee if applicable
        now = datetime.now()
        end_time = booking_data.get('endTime')
        overtime_fee = 0
        
        if end_time:
            end_dt = end_time.timestamp() if hasattr(end_time, 'timestamp') else end_time
            if now.timestamp() > end_dt:
                # Calculate overtime hours
                overtime_seconds = now.timestamp() - end_dt
                overtime_hours = overtime_seconds / 3600
                price_per_hour = booking_data.get('pricePerHour', 0)
                # Overtime charged at 1.5x rate
                overtime_fee = overtime_hours * price_per_hour * 1.5
        
        # Update booking
        update_data = {
            'status': 'completed',
            'checkedOutAt': firestore.SERVER_TIMESTAMP,
            'checkOutMethod': 'numberPlate',
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        if overtime_fee > 0:
            update_data['overtimeFee'] = round(overtime_fee, 2)
        
        db.collection('bookings').document(booking_id).update(update_data)
        
        # Increment available spots for parking location
        parking_spot_id = booking_data.get('parkingSpotId')
        if parking_spot_id:
            parking_ref = db.collection('parkingSpots').document(parking_spot_id)
            parking_ref.update({
                'availableSpots': firestore.Increment(1)
            })
        
        return jsonify({
            'success': True,
            'message': 'Check-out successful',
            'plate_number': plate_number,
            'booking_id': booking_id,
            'overtime_fee': overtime_fee if overtime_fee > 0 else None,
            'total_amount': booking_data.get('totalPrice', 0) + overtime_fee
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ============================================================================
# WEATHER RECOMMENDATION ENDPOINTS
# ============================================================================

@app.route('/api/weather', methods=['GET'])
def get_weather():
    """
    Get current weather for location
    
    Query params:
    - lat: Latitude
    - lon: Longitude
    """
    try:
        lat = float(request.args.get('lat', 17.385))
        lon = float(request.args.get('lon', 78.486))
        
        weather = weather_service.get_current_weather(lat, lon)
        
        if weather:
            return jsonify({
                'success': True,
                'weather': weather.to_dict()
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Could not fetch weather data'
            }), 503
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/recommendations', methods=['POST'])
def get_recommendations():
    """
    Get parking recommendations based on location and weather
    
    Request body:
    - latitude: User's latitude
    - longitude: User's longitude
    - parking_spots: List of parking spots (or fetch from DB)
    - preferences: User preferences (optional)
    """
    try:
        data = request.json or {}
        
        lat = data.get('latitude', 17.385)
        lon = data.get('longitude', 78.486)
        parking_spots = data.get('parking_spots', [])
        preferences = data.get('preferences', {})
        max_results = data.get('max_results', 10)
        
        # If no parking spots provided, fetch from Firebase
        if not parking_spots and db:
            spots_ref = db.collection('parkingSpots').where(
                'status', '==', 'available'
            ).limit(100)
            
            for doc in spots_ref.stream():
                spot_data = doc.to_dict()
                spot_data['id'] = doc.id
                parking_spots.append(spot_data)
        
        # Get recommendations
        recommendations = parking_recommender.get_recommendations(
            latitude=lat,
            longitude=lon,
            parking_spots=parking_spots,
            max_results=max_results,
            preferences=preferences
        )
        
        # Get weather summary
        weather_summary = parking_recommender.get_weather_summary(lat, lon)
        
        return jsonify({
            'success': True,
            'recommendations': [rec.to_dict() for rec in recommendations],
            'weather_summary': weather_summary,
            'total_spots_analyzed': len(parking_spots)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/weather-advice', methods=['GET'])
def get_weather_advice():
    """
    Get parking advice based on current weather
    
    Query params:
    - lat: Latitude
    - lon: Longitude
    """
    try:
        lat = float(request.args.get('lat', 17.385))
        lon = float(request.args.get('lon', 78.486))
        
        summary = parking_recommender.get_weather_summary(lat, lon)
        
        return jsonify({
            'success': True,
            **summary
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ============================================================================
# HEALTH CHECK
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'services': {
            'plate_detector': plate_detector.model is not None or True,
            'weather_service': weather_service.api_key is not None,
            'firebase': db is not None
        },
        'timestamp': datetime.now().isoformat()
    })


@app.route('/', methods=['GET'])
def index():
    """API documentation"""
    return jsonify({
        'name': 'Smart Parking API',
        'version': '1.0.0',
        'endpoints': {
            '/api/detect-plate': 'POST - Detect license plate from image',
            '/api/check-in': 'POST - Check-in vehicle by plate',
            '/api/check-out': 'POST - Check-out vehicle by plate',
            '/api/weather': 'GET - Get current weather',
            '/api/recommendations': 'POST - Get parking recommendations',
            '/api/weather-advice': 'GET - Get weather-based parking advice',
            '/health': 'GET - Health check'
        }
    })


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    print(f"Starting Smart Parking API on port {port}")
    print(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)

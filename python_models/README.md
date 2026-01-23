# Smart Parking - Python ML Models

This folder contains Python-based machine learning models for:
1. **Number Plate Recognition (ANPR)** - Automatic check-in/check-out by scanning vehicle number plates
2. **Weather-based Parking Recommendation** - Suggests optimal parking spots based on weather conditions

## Setup

### 1. Create Virtual Environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Download Pre-trained Models
```bash
python download_models.py
```

### 4. Configure Environment
Create a `.env` file:
```env
FIREBASE_CREDENTIALS_PATH=path/to/serviceAccountKey.json
WEATHER_API_KEY=your_openweathermap_api_key
MODEL_PATH=./models
```

## Models

### Number Plate Recognition

The ANPR system uses:
- **YOLOv8** for license plate detection
- **EasyOCR** for text extraction from plates

#### Usage
```python
from number_plate_recognition.plate_detector import PlateDetector

detector = PlateDetector()
result = detector.detect_plate("path/to/image.jpg")
print(result)  # {'plate_number': 'KA01AB1234', 'confidence': 0.95}
```

#### API Endpoints
- `POST /api/detect-plate` - Detect plate from image
- `POST /api/check-in` - Check-in vehicle by plate number
- `POST /api/check-out` - Check-out vehicle by plate number

### Weather Recommendation

The recommendation system considers:
- Current weather conditions (rain, temperature, humidity)
- Parking spot features (covered, open-air, underground)
- Historical occupancy data

#### Usage
```python
from weather_recommendation.recommender import ParkingRecommender

recommender = ParkingRecommender()
recommendations = recommender.get_recommendations(
    latitude=17.385,
    longitude=78.486
)
```

## API Server

Start the API server:
```bash
python api_server.py
```

Server runs on `http://localhost:5000`

## Directory Structure
```
python_models/
├── number_plate_recognition/
│   ├── __init__.py
│   ├── plate_detector.py      # Main detection class
│   ├── ocr_engine.py          # OCR text extraction
│   └── utils.py               # Helper functions
├── weather_recommendation/
│   ├── __init__.py
│   ├── recommender.py         # Main recommendation class
│   ├── weather_api.py         # Weather data fetching
│   └── feature_extractor.py   # Feature engineering
├── data/
│   └── (datasets will be here)
├── models/
│   └── (trained models will be here)
├── api_server.py              # Flask API server
├── download_models.py         # Script to download pre-trained models
├── requirements.txt
└── README.md
```

## Training Custom Models

### Number Plate Detection
To train on Indian license plates:
```bash
python train_plate_detector.py --data ./data/indian_plates --epochs 100
```

### Weather Recommendation
To train the recommendation model:
```bash
python train_recommender.py --data ./data/parking_history.csv
```

## Integration with Flutter App

The Flutter app communicates with this API for:
1. **Check-in**: Camera captures vehicle, sends to `/api/detect-plate`, matches with bookings
2. **Check-out**: Same process, marks booking as completed
3. **Recommendations**: Fetches weather-aware parking suggestions

## License
Proprietary - QuickPark Smart Parking System

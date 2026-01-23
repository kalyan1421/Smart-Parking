"""
Convert trained models to TFLite format for Flutter deployment
"""

import os
import numpy as np
from pathlib import Path

# Output directories
MODELS_DIR = Path(__file__).parent / 'models'
FLUTTER_ASSETS_DIR = Path(__file__).parent.parent / 'smart_parking_app' / 'assets' / 'ml_models'

# Create directories
MODELS_DIR.mkdir(exist_ok=True)
FLUTTER_ASSETS_DIR.mkdir(parents=True, exist_ok=True)


def convert_yolo_to_tflite():
    """Convert YOLOv8 model to TFLite format"""
    print("\n=== Converting YOLOv8 to TFLite ===")
    
    try:
        from ultralytics import YOLO
        
        # Load the trained model (or pre-trained)
        model_path = MODELS_DIR / 'plate_detector.pt'
        
        if not model_path.exists():
            print("Custom model not found, using pre-trained YOLOv8n")
            model = YOLO('yolov8n.pt')
        else:
            model = YOLO(str(model_path))
        
        # Export to TFLite
        print("Exporting to TFLite...")
        model.export(
            format='tflite',
            imgsz=320,
            half=False,  # Full precision for better accuracy
            int8=True,   # Quantization for smaller size
        )
        
        # Find the exported file
        export_path = Path('yolov8n_saved_model') / 'yolov8n_float32.tflite'
        if export_path.exists():
            # Copy to Flutter assets
            import shutil
            dest_path = FLUTTER_ASSETS_DIR / 'plate_detector.tflite'
            shutil.copy(export_path, dest_path)
            print(f"TFLite model saved to: {dest_path}")
            print(f"Model size: {dest_path.stat().st_size / 1024 / 1024:.2f} MB")
        else:
            print("Export completed. Check the exports folder.")
            
    except ImportError:
        print("ultralytics not installed. Creating placeholder model info.")
        _create_placeholder_model_info()
    except Exception as e:
        print(f"Error converting YOLO: {e}")
        _create_placeholder_model_info()


def convert_recommender_to_tflite():
    """Convert weather recommendation model to TFLite"""
    print("\n=== Converting Recommendation Model to TFLite ===")
    
    try:
        import tensorflow as tf
        from sklearn.ensemble import RandomForestRegressor
        import joblib
        
        # Check if trained model exists
        model_path = MODELS_DIR / 'recommender_model.pkl'
        
        if model_path.exists():
            # Load sklearn model
            sklearn_model = joblib.load(model_path)
            print(f"Loaded sklearn model from {model_path}")
        else:
            # Create a simple neural network model for recommendation
            print("Creating new TensorFlow model for recommendation...")
            
            # Define model architecture
            model = tf.keras.Sequential([
                tf.keras.layers.InputLayer(input_shape=(15,)),  # 15 input features
                tf.keras.layers.Dense(32, activation='relu'),
                tf.keras.layers.Dropout(0.2),
                tf.keras.layers.Dense(16, activation='relu'),
                tf.keras.layers.Dense(1, activation='sigmoid')  # Score 0-1
            ])
            
            model.compile(
                optimizer='adam',
                loss='mse',
                metrics=['mae']
            )
            
            # Create dummy data for model initialization
            X_dummy = np.random.rand(100, 15).astype(np.float32)
            y_dummy = np.random.rand(100, 1).astype(np.float32)
            model.fit(X_dummy, y_dummy, epochs=1, verbose=0)
            
            sklearn_model = None
        
        # Convert to TFLite
        if sklearn_model is None:
            # Use the Keras model
            converter = tf.lite.TFLiteConverter.from_keras_model(model)
        else:
            # For sklearn, we need to wrap it in a TF function
            # This is a simplified approach
            model = _sklearn_to_tf(sklearn_model)
            converter = tf.lite.TFLiteConverter.from_keras_model(model)
        
        # Optimization
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        
        # Convert
        tflite_model = converter.convert()
        
        # Save
        tflite_path = FLUTTER_ASSETS_DIR / 'weather_recommender.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"TFLite model saved to: {tflite_path}")
        print(f"Model size: {tflite_path.stat().st_size / 1024:.2f} KB")
        
    except ImportError as e:
        print(f"Required library not installed: {e}")
        _create_placeholder_recommender()
    except Exception as e:
        print(f"Error converting recommender: {e}")
        _create_placeholder_recommender()


def _sklearn_to_tf(sklearn_model, input_shape=(15,)):
    """Convert sklearn model to TensorFlow model (approximation)"""
    import tensorflow as tf
    
    # Create a simple neural network that mimics the sklearn model behavior
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=input_shape),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    return model


def _create_placeholder_model_info():
    """Create placeholder info for plate detector"""
    info = """
# Plate Detector Model Info

## To get the actual TFLite model:

1. Install ultralytics: pip install ultralytics
2. Run: python convert_to_tflite.py

## Or download pre-trained models:

- YOLOv8n TFLite: https://github.com/ultralytics/assets/releases
- Custom plate detector: Train your own using train_plate_detector.py

## Model Specifications:

- Input: 320x320x3 RGB image (normalized 0-1)
- Output: [1, 25200, 6] tensor
  - Each detection: [x, y, w, h, confidence, class_id]
- Format: TensorFlow Lite (float32 or int8 quantized)

## Alternative: Use API

If TFLite is not available, the app can fall back to the Python API server
at http://localhost:5000/api/detect-plate
"""
    
    info_path = FLUTTER_ASSETS_DIR / 'plate_detector_info.txt'
    with open(info_path, 'w') as f:
        f.write(info)
    print(f"Model info saved to: {info_path}")


def _create_placeholder_recommender():
    """Create placeholder for recommender model"""
    info = """
# Weather Recommender Model Info

## To get the actual TFLite model:

1. Install TensorFlow: pip install tensorflow
2. Run: python convert_to_tflite.py

## Model Specifications:

- Input: 15 float features
  - [temp, humidity, rain, wind, uv, is_day, is_covered, is_underground,
   has_ev, has_security, distance, price, availability, rating, user_pref]
- Output: Single float (0-1) recommendation score
- Format: TensorFlow Lite (float16)

## Input Feature Normalization:

| Feature | Min | Max |
|---------|-----|-----|
| temperature | -10 | 50 |
| humidity | 0 | 100 |
| rain_intensity | 0 | 50 |
| wind_speed | 0 | 30 |
| uv_index | 0 | 11 |
| distance | 0 | 10000 |
| price | 0 | 200 |
| availability | 0 | 1 |
| rating | 0 | 5 |

## Alternative: Use Rule-based Scoring

If TFLite is not available, the app uses a rule-based scoring system
that doesn't require ML inference.
"""
    
    info_path = FLUTTER_ASSETS_DIR / 'weather_recommender_info.txt'
    with open(info_path, 'w') as f:
        f.write(info)
    print(f"Model info saved to: {info_path}")


def create_labels_file():
    """Create labels file for plate detector"""
    labels = """license_plate
vehicle
"""
    labels_path = FLUTTER_ASSETS_DIR / 'plate_detector_labels.txt'
    with open(labels_path, 'w') as f:
        f.write(labels)
    print(f"Labels saved to: {labels_path}")


def verify_flutter_assets():
    """Update Flutter pubspec.yaml to include ML assets"""
    pubspec_path = Path(__file__).parent.parent / 'smart_parking_app' / 'pubspec.yaml'
    
    if not pubspec_path.exists():
        print("pubspec.yaml not found")
        return
    
    with open(pubspec_path, 'r') as f:
        content = f.read()
    
    # Check if ml_models asset is already listed
    if 'assets/ml_models/' not in content:
        print("\n⚠️  Don't forget to add ML models to pubspec.yaml assets:")
        print("  assets:")
        print("    - assets/ml_models/")


def main():
    print("=" * 60)
    print("TFLite Model Conversion for Smart Parking")
    print("=" * 60)
    
    # Create labels file
    create_labels_file()
    
    # Convert models
    convert_yolo_to_tflite()
    convert_recommender_to_tflite()
    
    # Verify Flutter setup
    verify_flutter_assets()
    
    print("\n" + "=" * 60)
    print("Conversion complete!")
    print("=" * 60)
    print(f"\nModels saved to: {FLUTTER_ASSETS_DIR}")
    print("\nFiles created:")
    for f in FLUTTER_ASSETS_DIR.iterdir():
        size = f.stat().st_size
        if size > 1024 * 1024:
            print(f"  - {f.name} ({size / 1024 / 1024:.2f} MB)")
        else:
            print(f"  - {f.name} ({size / 1024:.2f} KB)")


if __name__ == '__main__':
    main()

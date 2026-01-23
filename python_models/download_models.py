"""
Download pre-trained models and sample datasets for Smart Parking ML
"""

import os
import urllib.request
import zipfile
from pathlib import Path

# Directories
BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / 'models'
DATA_DIR = BASE_DIR / 'data'

# Create directories
MODELS_DIR.mkdir(exist_ok=True)
DATA_DIR.mkdir(exist_ok=True)


def download_file(url: str, dest: str, desc: str = ""):
    """Download file with progress"""
    print(f"Downloading {desc or url}...")
    try:
        urllib.request.urlretrieve(url, dest)
        print(f"  Saved to {dest}")
        return True
    except Exception as e:
        print(f"  Failed: {e}")
        return False


def setup_yolo_model():
    """Download YOLOv8 model for object detection"""
    print("\n=== Setting up YOLOv8 model ===")
    
    try:
        from ultralytics import YOLO
        
        # Download the nano model (smallest, fastest)
        model_path = MODELS_DIR / 'yolov8n.pt'
        
        if not model_path.exists():
            print("Downloading YOLOv8 nano model...")
            model = YOLO('yolov8n.pt')  # This auto-downloads
            # Move to our models directory
            import shutil
            default_path = Path.home() / '.ultralytics' / 'hub' / 'yolov8n.pt'
            if default_path.exists():
                shutil.copy(default_path, model_path)
            print(f"Model saved to {model_path}")
        else:
            print("YOLOv8 model already exists")
            
    except ImportError:
        print("ultralytics not installed. Run: pip install ultralytics")
    except Exception as e:
        print(f"Error setting up YOLO: {e}")


def setup_easyocr():
    """Initialize EasyOCR (downloads models on first use)"""
    print("\n=== Setting up EasyOCR ===")
    
    try:
        import easyocr
        
        print("Initializing EasyOCR (this will download language models)...")
        reader = easyocr.Reader(['en'], gpu=False, verbose=True)
        print("EasyOCR setup complete")
        
    except ImportError:
        print("easyocr not installed. Run: pip install easyocr")
    except Exception as e:
        print(f"Error setting up EasyOCR: {e}")


def download_sample_data():
    """Download sample datasets for training/testing"""
    print("\n=== Downloading sample data ===")
    
    # Indian license plate dataset info
    datasets = [
        {
            'name': 'Indian License Plate Dataset',
            'url': 'https://github.com/openalpr/benchmarks/raw/master/endtoend/in.zip',
            'dest': DATA_DIR / 'indian_plates.zip',
            'note': 'Sample Indian license plate images for testing'
        }
    ]
    
    for dataset in datasets:
        dest = dataset['dest']
        if dest.exists():
            print(f"{dataset['name']} already exists")
            continue
        
        print(f"\n{dataset['name']}: {dataset['note']}")
        success = download_file(str(dataset['url']), str(dest), dataset['name'])
        
        if success and str(dest).endswith('.zip'):
            print(f"Extracting {dest}...")
            try:
                with zipfile.ZipFile(dest, 'r') as zip_ref:
                    zip_ref.extractall(DATA_DIR)
                print("Extraction complete")
            except Exception as e:
                print(f"Extraction failed: {e}")


def create_sample_env():
    """Create sample .env file"""
    print("\n=== Creating sample .env file ===")
    
    env_path = BASE_DIR / '.env.example'
    
    env_content = """# Smart Parking ML Configuration

# Firebase credentials path
FIREBASE_CREDENTIALS_PATH=./serviceAccountKey.json

# OpenWeatherMap API key (get free key at https://openweathermap.org/api)
WEATHER_API_KEY=your_api_key_here

# Model paths
YOLO_MODEL_PATH=./models/yolov8n.pt
RECOMMENDER_MODEL_PATH=./models/recommender_model.pkl

# Server configuration
PORT=5000
FLASK_DEBUG=false
"""
    
    with open(env_path, 'w') as f:
        f.write(env_content)
    
    print(f"Created {env_path}")
    print("Copy to .env and fill in your API keys")


def verify_installation():
    """Verify all components are properly installed"""
    print("\n=== Verifying Installation ===")
    
    checks = []
    
    # Check Python packages
    packages = [
        ('numpy', 'NumPy'),
        ('cv2', 'OpenCV'),
        ('flask', 'Flask'),
        ('requests', 'Requests'),
    ]
    
    optional_packages = [
        ('ultralytics', 'YOLOv8 (ultralytics)'),
        ('easyocr', 'EasyOCR'),
        ('torch', 'PyTorch'),
        ('sklearn', 'scikit-learn'),
        ('firebase_admin', 'Firebase Admin SDK'),
    ]
    
    print("\nRequired packages:")
    for pkg, name in packages:
        try:
            __import__(pkg)
            print(f"  ✓ {name}")
            checks.append((name, True))
        except ImportError:
            print(f"  ✗ {name} - NOT INSTALLED")
            checks.append((name, False))
    
    print("\nOptional packages:")
    for pkg, name in optional_packages:
        try:
            __import__(pkg)
            print(f"  ✓ {name}")
        except ImportError:
            print(f"  ○ {name} - not installed (optional)")
    
    # Check model files
    print("\nModel files:")
    model_files = [
        (MODELS_DIR / 'yolov8n.pt', 'YOLOv8 nano model'),
    ]
    
    for path, name in model_files:
        if path.exists():
            print(f"  ✓ {name}")
        else:
            print(f"  ○ {name} - not downloaded yet")
    
    # Summary
    required_ok = all(ok for _, ok in checks)
    
    print("\n" + "=" * 50)
    if required_ok:
        print("✓ All required components installed!")
        print("Run 'python api_server.py' to start the server")
    else:
        print("✗ Some required components are missing")
        print("Run 'pip install -r requirements.txt' to install")
    print("=" * 50)


def main():
    print("=" * 60)
    print("Smart Parking ML Setup")
    print("=" * 60)
    
    # Setup steps
    setup_yolo_model()
    setup_easyocr()
    download_sample_data()
    create_sample_env()
    verify_installation()
    
    print("\n\nSetup complete!")
    print("\nNext steps:")
    print("1. Copy .env.example to .env")
    print("2. Add your OpenWeatherMap API key")
    print("3. Add Firebase credentials (serviceAccountKey.json)")
    print("4. Run: python api_server.py")


if __name__ == '__main__':
    main()

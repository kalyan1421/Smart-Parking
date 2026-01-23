#!/usr/bin/env python3
"""
Download datasets for Smart Parking ML models

Datasets:
1. Indian License Plates - For ANPR model training
2. Weather Data - For recommendation model (optional)

Usage:
    python download_datasets.py --dataset indian_plates
    python download_datasets.py --dataset all
    python download_datasets.py --list
"""

import os
import sys
import argparse
import zipfile
import tarfile
import shutil
from pathlib import Path
from urllib.request import urlretrieve
from urllib.error import URLError

# Base paths
BASE_DIR = Path(__file__).parent
DATASETS_DIR = BASE_DIR / 'datasets'
MODELS_DIR = BASE_DIR / 'models'

# Dataset configurations
DATASETS = {
    'indian_plates': {
        'name': 'Indian License Plate Dataset',
        'description': 'Collection of Indian vehicle license plate images for ANPR training',
        'sources': [
            {
                'name': 'OpenALPR Benchmark (India subset)',
                'url': 'https://github.com/openalpr/benchmarks/archive/refs/heads/master.zip',
                'type': 'zip',
                'extract_path': 'openalpr_benchmarks',
            },
            {
                'name': 'Sample Indian Plates (Kaggle-style)',
                'url': None,  # Will use synthetic data generation
                'type': 'synthetic',
            }
        ],
        'output_dir': 'indian_plates',
    },
    'yolo_pretrained': {
        'name': 'YOLOv8 Pre-trained Weights',
        'description': 'Pre-trained YOLOv8 nano model for transfer learning',
        'sources': [
            {
                'name': 'YOLOv8n',
                'url': 'https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.pt',
                'type': 'direct',
                'output_name': 'yolov8n.pt',
            }
        ],
        'output_dir': 'pretrained',
    },
    'ocr_models': {
        'name': 'OCR Models',
        'description': 'EasyOCR and Tesseract language models',
        'sources': [
            {
                'name': 'EasyOCR English Model',
                'url': None,  # Downloaded automatically by EasyOCR
                'type': 'easyocr',
            }
        ],
        'output_dir': 'ocr',
    }
}


def create_directories():
    """Create necessary directories"""
    DATASETS_DIR.mkdir(exist_ok=True)
    MODELS_DIR.mkdir(exist_ok=True)
    print(f"Datasets directory: {DATASETS_DIR}")
    print(f"Models directory: {MODELS_DIR}")


def download_file(url: str, output_path: Path, description: str = "file") -> bool:
    """Download a file with progress indicator"""
    print(f"\nDownloading {description}...")
    print(f"URL: {url}")
    print(f"Output: {output_path}")
    
    try:
        def progress_hook(count, block_size, total_size):
            if total_size > 0:
                percent = min(100, count * block_size * 100 // total_size)
                bar = '=' * (percent // 2) + '>' + ' ' * (50 - percent // 2)
                sys.stdout.write(f'\r[{bar}] {percent}%')
                sys.stdout.flush()
        
        output_path.parent.mkdir(parents=True, exist_ok=True)
        urlretrieve(url, output_path, progress_hook)
        print(f"\nDownloaded: {output_path.stat().st_size / 1024 / 1024:.2f} MB")
        return True
        
    except URLError as e:
        print(f"\nFailed to download: {e}")
        return False
    except Exception as e:
        print(f"\nError: {e}")
        return False


def extract_archive(archive_path: Path, output_dir: Path, archive_type: str) -> bool:
    """Extract zip or tar archive"""
    print(f"Extracting {archive_path} to {output_dir}...")
    
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
        
        if archive_type == 'zip':
            with zipfile.ZipFile(archive_path, 'r') as zf:
                zf.extractall(output_dir)
        elif archive_type in ('tar', 'tar.gz', 'tgz'):
            with tarfile.open(archive_path, 'r:*') as tf:
                tf.extractall(output_dir)
        else:
            print(f"Unknown archive type: {archive_type}")
            return False
        
        print(f"Extracted successfully")
        return True
        
    except Exception as e:
        print(f"Extraction failed: {e}")
        return False


def generate_synthetic_plates(output_dir: Path, count: int = 100):
    """Generate synthetic Indian license plate images for testing"""
    print(f"\nGenerating {count} synthetic plate images...")
    
    try:
        from PIL import Image, ImageDraw, ImageFont
        import random
        import string
    except ImportError:
        print("PIL not installed. Installing...")
        os.system(f"{sys.executable} -m pip install Pillow")
        from PIL import Image, ImageDraw, ImageFont
        import random
        import string
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Indian state codes
    state_codes = ['KA', 'MH', 'DL', 'TN', 'AP', 'TS', 'GJ', 'RJ', 'UP', 'MP', 'WB', 'KL', 'PB', 'HR']
    
    # Create labels file for YOLO training
    labels_dir = output_dir / 'labels'
    images_dir = output_dir / 'images'
    labels_dir.mkdir(exist_ok=True)
    images_dir.mkdir(exist_ok=True)
    
    generated = 0
    for i in range(count):
        try:
            # Generate random plate number
            state = random.choice(state_codes)
            district = f"{random.randint(1, 99):02d}"
            series = ''.join(random.choices(string.ascii_uppercase, k=random.randint(1, 2)))
            number = f"{random.randint(1, 9999):04d}"
            plate_text = f"{state}{district}{series}{number}"
            
            # Create image
            img_width, img_height = 520, 110
            img = Image.new('RGB', (img_width, img_height), color='white')
            draw = ImageDraw.Draw(img)
            
            # Add border
            draw.rectangle([2, 2, img_width-3, img_height-3], outline='black', width=3)
            
            # Add text
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 60)
            except:
                font = ImageFont.load_default()
            
            # Format: "KA 01 AB 1234"
            formatted_text = f"{state} {district} {series} {number}"
            bbox = draw.textbbox((0, 0), formatted_text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            x = (img_width - text_width) // 2
            y = (img_height - text_height) // 2 - 10
            draw.text((x, y), formatted_text, fill='black', font=font)
            
            # Add some noise/variations
            if random.random() > 0.7:
                # Add slight rotation
                angle = random.uniform(-3, 3)
                img = img.rotate(angle, fillcolor='white', expand=False)
            
            # Save image
            img_path = images_dir / f"plate_{i:04d}.jpg"
            img.save(img_path, 'JPEG', quality=90)
            
            # Create YOLO label (normalized bbox)
            # Full plate occupies most of the image
            label_path = labels_dir / f"plate_{i:04d}.txt"
            # YOLO format: class x_center y_center width height (normalized)
            with open(label_path, 'w') as f:
                f.write(f"0 0.5 0.5 0.9 0.8\n")  # class 0 = license_plate
            
            generated += 1
            
        except Exception as e:
            print(f"Error generating plate {i}: {e}")
            continue
    
    print(f"Generated {generated} synthetic plates in {images_dir}")
    
    # Create dataset YAML for YOLO training
    yaml_content = f"""# Indian License Plate Dataset
# Auto-generated for training

path: {output_dir}
train: images
val: images

names:
  0: license_plate
"""
    yaml_path = output_dir / 'indian_plates.yaml'
    with open(yaml_path, 'w') as f:
        f.write(yaml_content)
    print(f"Created dataset config: {yaml_path}")
    
    return generated > 0


def download_easyocr_models():
    """Download EasyOCR models"""
    print("\nSetting up EasyOCR models...")
    
    try:
        import easyocr
        print("Downloading English OCR model (this may take a while)...")
        reader = easyocr.Reader(['en'], gpu=False)
        print("EasyOCR models downloaded successfully")
        return True
    except ImportError:
        print("EasyOCR not installed. Run: pip install easyocr")
        return False
    except Exception as e:
        print(f"Error setting up EasyOCR: {e}")
        return False


def download_dataset(dataset_name: str) -> bool:
    """Download a specific dataset"""
    if dataset_name not in DATASETS:
        print(f"Unknown dataset: {dataset_name}")
        print(f"Available: {', '.join(DATASETS.keys())}")
        return False
    
    config = DATASETS[dataset_name]
    print(f"\n{'='*60}")
    print(f"Dataset: {config['name']}")
    print(f"Description: {config['description']}")
    print('='*60)
    
    output_dir = DATASETS_DIR / config['output_dir']
    success = True
    
    for source in config['sources']:
        print(f"\nSource: {source['name']}")
        
        if source['type'] == 'direct':
            # Direct file download
            output_path = MODELS_DIR / source.get('output_name', source['url'].split('/')[-1])
            if output_path.exists():
                print(f"Already exists: {output_path}")
            else:
                success &= download_file(source['url'], output_path, source['name'])
                
        elif source['type'] == 'zip':
            # Download and extract zip
            if source['url']:
                archive_path = DATASETS_DIR / f"{dataset_name}.zip"
                if not archive_path.exists():
                    success &= download_file(source['url'], archive_path, source['name'])
                if archive_path.exists():
                    success &= extract_archive(archive_path, output_dir, 'zip')
            else:
                print("No URL provided, skipping...")
                
        elif source['type'] == 'synthetic':
            # Generate synthetic data
            success &= generate_synthetic_plates(output_dir)
            
        elif source['type'] == 'easyocr':
            # Download EasyOCR models
            success &= download_easyocr_models()
            
        else:
            print(f"Unknown source type: {source['type']}")
    
    return success


def list_datasets():
    """List available datasets"""
    print("\nAvailable Datasets:")
    print("="*60)
    for name, config in DATASETS.items():
        print(f"\n{name}:")
        print(f"  Name: {config['name']}")
        print(f"  Description: {config['description']}")
        print(f"  Sources: {len(config['sources'])}")


def main():
    parser = argparse.ArgumentParser(
        description='Download datasets for Smart Parking ML models',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python download_datasets.py --dataset indian_plates
  python download_datasets.py --dataset yolo_pretrained
  python download_datasets.py --dataset all
  python download_datasets.py --list
        """
    )
    
    parser.add_argument(
        '--dataset', '-d',
        type=str,
        help='Dataset to download (or "all" for all datasets)'
    )
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='List available datasets'
    )
    parser.add_argument(
        '--synthetic-count', '-n',
        type=int,
        default=500,
        help='Number of synthetic plates to generate (default: 500)'
    )
    
    args = parser.parse_args()
    
    if args.list:
        list_datasets()
        return
    
    if not args.dataset:
        parser.print_help()
        return
    
    # Create directories
    create_directories()
    
    # Download datasets
    if args.dataset.lower() == 'all':
        for name in DATASETS:
            download_dataset(name)
    else:
        download_dataset(args.dataset)
    
    print("\n" + "="*60)
    print("Download complete!")
    print("="*60)
    print(f"\nDatasets location: {DATASETS_DIR}")
    print(f"Models location: {MODELS_DIR}")
    print("\nNext steps:")
    print("1. Train ANPR model: python train_plate_detector.py")
    print("2. Convert to TFLite: python convert_to_tflite.py")


if __name__ == '__main__':
    main()

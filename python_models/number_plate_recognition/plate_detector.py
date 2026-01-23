"""
Number Plate Detection using YOLOv8
Detects and extracts vehicle license plates from images/video frames
"""

import cv2
import numpy as np
from pathlib import Path
from typing import Optional, Dict, List, Tuple
import os

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None

from .ocr_engine import OCREngine
from .utils import preprocess_image, validate_plate_format


class PlateDetector:
    """
    Automatic Number Plate Recognition (ANPR) system
    Uses YOLOv8 for plate detection and EasyOCR for text extraction
    """
    
    def __init__(self, model_path: Optional[str] = None):
        """
        Initialize the plate detector
        
        Args:
            model_path: Path to custom trained YOLO model (optional)
        """
        self.model_path = model_path or os.getenv('YOLO_MODEL_PATH', 'yolov8n.pt')
        self.model = None
        self.ocr_engine = OCREngine()
        self.confidence_threshold = 0.5
        
        self._load_model()
    
    def _load_model(self):
        """Load the YOLO model for plate detection"""
        try:
            if YOLO is None:
                print("Warning: ultralytics not installed. Using fallback detection.")
                return
            
            # Check if custom plate detection model exists
            custom_model_path = Path(__file__).parent.parent / 'models' / 'plate_detector.pt'
            
            if custom_model_path.exists():
                self.model = YOLO(str(custom_model_path))
                print(f"Loaded custom plate detection model from {custom_model_path}")
            else:
                # Use pre-trained YOLOv8 model
                self.model = YOLO(self.model_path)
                print(f"Loaded YOLOv8 model: {self.model_path}")
                
        except Exception as e:
            print(f"Error loading YOLO model: {e}")
            self.model = None
    
    def detect_plate(self, image_source: str | np.ndarray) -> Dict:
        """
        Detect and extract license plate from image
        
        Args:
            image_source: Path to image file or numpy array
            
        Returns:
            Dict with plate_number, confidence, bbox, and raw_image
        """
        # Load image
        if isinstance(image_source, str):
            image = cv2.imread(image_source)
        else:
            image = image_source.copy()
        
        if image is None:
            return {'error': 'Could not load image', 'plate_number': None}
        
        # Preprocess
        processed = preprocess_image(image)
        
        # Detect plates
        plates = self._detect_plates_in_image(processed)
        
        if not plates:
            # Fallback: Try edge detection method
            plates = self._fallback_plate_detection(processed)
        
        if not plates:
            return {
                'plate_number': None,
                'confidence': 0.0,
                'error': 'No license plate detected'
            }
        
        # Get the most confident detection
        best_plate = max(plates, key=lambda x: x['confidence'])
        
        # Extract text using OCR
        plate_text = self.ocr_engine.extract_text(best_plate['crop'])
        
        # Validate Indian plate format
        validated_text, is_valid = validate_plate_format(plate_text)
        
        return {
            'plate_number': validated_text if validated_text else plate_text,
            'confidence': best_plate['confidence'] * (0.9 if is_valid else 0.7),
            'bbox': best_plate['bbox'],
            'is_valid_format': is_valid,
            'raw_text': plate_text
        }
    
    def _detect_plates_in_image(self, image: np.ndarray) -> List[Dict]:
        """
        Use YOLO to detect license plates
        
        Returns list of detected plates with bounding boxes
        """
        plates = []
        
        if self.model is None:
            return plates
        
        try:
            # Run YOLO detection
            results = self.model(image, verbose=False)
            
            for result in results:
                boxes = result.boxes
                if boxes is None:
                    continue
                
                for box in boxes:
                    # Filter for vehicle-related classes or high confidence detections
                    confidence = float(box.conf[0])
                    
                    if confidence < self.confidence_threshold:
                        continue
                    
                    # Get bounding box
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    
                    # Extract plate region with padding
                    pad = 10
                    h, w = image.shape[:2]
                    x1 = max(0, x1 - pad)
                    y1 = max(0, y1 - pad)
                    x2 = min(w, x2 + pad)
                    y2 = min(h, y2 + pad)
                    
                    crop = image[y1:y2, x1:x2]
                    
                    if crop.size > 0:
                        plates.append({
                            'bbox': (x1, y1, x2, y2),
                            'confidence': confidence,
                            'crop': crop
                        })
                        
        except Exception as e:
            print(f"YOLO detection error: {e}")
        
        return plates
    
    def _fallback_plate_detection(self, image: np.ndarray) -> List[Dict]:
        """
        Fallback plate detection using traditional CV methods
        Used when YOLO model is not available or fails
        """
        plates = []
        
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Apply bilateral filter to reduce noise
            gray = cv2.bilateralFilter(gray, 11, 17, 17)
            
            # Edge detection
            edges = cv2.Canny(gray, 30, 200)
            
            # Find contours
            contours, _ = cv2.findContours(
                edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE
            )
            
            # Sort contours by area
            contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
            
            for contour in contours:
                # Approximate the contour
                peri = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.018 * peri, True)
                
                # License plates typically have 4 corners
                if len(approx) == 4:
                    x, y, w, h = cv2.boundingRect(approx)
                    
                    # Check aspect ratio (Indian plates are typically 4.7:1 or 2:1)
                    aspect_ratio = w / h if h > 0 else 0
                    
                    if 1.5 < aspect_ratio < 6.0 and w > 100:
                        # Add padding
                        pad = 5
                        ih, iw = image.shape[:2]
                        x1 = max(0, x - pad)
                        y1 = max(0, y - pad)
                        x2 = min(iw, x + w + pad)
                        y2 = min(ih, y + h + pad)
                        
                        crop = image[y1:y2, x1:x2]
                        
                        if crop.size > 0:
                            plates.append({
                                'bbox': (x1, y1, x2, y2),
                                'confidence': 0.6,  # Lower confidence for fallback
                                'crop': crop
                            })
                            
        except Exception as e:
            print(f"Fallback detection error: {e}")
        
        return plates
    
    def detect_from_video_frame(self, frame: np.ndarray) -> Dict:
        """
        Optimized detection for video frames (real-time processing)
        """
        # Resize for faster processing
        h, w = frame.shape[:2]
        scale = min(640 / w, 480 / h)
        
        if scale < 1:
            resized = cv2.resize(frame, None, fx=scale, fy=scale)
        else:
            resized = frame
        
        result = self.detect_plate(resized)
        
        # Scale bbox back to original size if needed
        if scale < 1 and result.get('bbox'):
            x1, y1, x2, y2 = result['bbox']
            result['bbox'] = (
                int(x1 / scale),
                int(y1 / scale),
                int(x2 / scale),
                int(y2 / scale)
            )
        
        return result
    
    def batch_detect(self, images: List[str | np.ndarray]) -> List[Dict]:
        """
        Detect plates from multiple images
        """
        return [self.detect_plate(img) for img in images]


# Quick test
if __name__ == '__main__':
    detector = PlateDetector()
    
    # Test with a sample image if available
    test_image = Path(__file__).parent.parent / 'data' / 'test_plate.jpg'
    
    if test_image.exists():
        result = detector.detect_plate(str(test_image))
        print(f"Detection result: {result}")
    else:
        print("No test image found. Please add a test image to data/test_plate.jpg")

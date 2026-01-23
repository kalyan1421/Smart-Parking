"""
OCR Engine for License Plate Text Extraction
Uses EasyOCR with fallback to Tesseract
"""

import cv2
import numpy as np
from typing import Optional, List, Tuple
import re

try:
    import easyocr
    EASYOCR_AVAILABLE = True
except ImportError:
    EASYOCR_AVAILABLE = False

try:
    import pytesseract
    TESSERACT_AVAILABLE = True
except ImportError:
    TESSERACT_AVAILABLE = False


class OCREngine:
    """
    OCR engine optimized for Indian license plate recognition
    Supports multiple OCR backends with automatic fallback
    """
    
    def __init__(self, languages: List[str] = None):
        """
        Initialize OCR engine
        
        Args:
            languages: List of language codes (default: ['en'])
        """
        self.languages = languages or ['en']
        self.reader = None
        
        self._initialize_ocr()
    
    def _initialize_ocr(self):
        """Initialize the OCR reader"""
        if EASYOCR_AVAILABLE:
            try:
                self.reader = easyocr.Reader(
                    self.languages,
                    gpu=False,  # Set to True if GPU available
                    verbose=False
                )
                print("EasyOCR initialized successfully")
            except Exception as e:
                print(f"EasyOCR initialization failed: {e}")
                self.reader = None
        else:
            print("EasyOCR not available, will use Tesseract fallback")
    
    def extract_text(self, image: np.ndarray) -> str:
        """
        Extract text from license plate image
        
        Args:
            image: Cropped license plate image (numpy array)
            
        Returns:
            Extracted and cleaned plate text
        """
        if image is None or image.size == 0:
            return ""
        
        # Preprocess for better OCR
        processed = self._preprocess_for_ocr(image)
        
        # Try EasyOCR first
        text = self._extract_with_easyocr(processed)
        
        # Fallback to Tesseract if EasyOCR fails
        if not text and TESSERACT_AVAILABLE:
            text = self._extract_with_tesseract(processed)
        
        # Clean and format the text
        cleaned_text = self._clean_plate_text(text)
        
        return cleaned_text
    
    def _preprocess_for_ocr(self, image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for better OCR accuracy
        """
        # Convert to grayscale if needed
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()
        
        # Resize for better OCR (optimal around 300-400 DPI)
        h, w = gray.shape
        if w < 200:
            scale = 200 / w
            gray = cv2.resize(gray, None, fx=scale, fy=scale, 
                            interpolation=cv2.INTER_CUBIC)
        
        # Apply adaptive thresholding
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 11, 2
        )
        
        # Denoise
        denoised = cv2.fastNlMeansDenoising(binary, None, 10, 7, 21)
        
        # Morphological operations to clean up
        kernel = np.ones((2, 2), np.uint8)
        cleaned = cv2.morphologyEx(denoised, cv2.MORPH_CLOSE, kernel)
        
        return cleaned
    
    def _extract_with_easyocr(self, image: np.ndarray) -> str:
        """Extract text using EasyOCR"""
        if self.reader is None:
            return ""
        
        try:
            # Run OCR
            results = self.reader.readtext(
                image,
                detail=0,  # Return only text
                paragraph=False,
                allowlist='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            )
            
            # Combine all detected text
            text = ''.join(results)
            return text
            
        except Exception as e:
            print(f"EasyOCR extraction error: {e}")
            return ""
    
    def _extract_with_tesseract(self, image: np.ndarray) -> str:
        """Extract text using Tesseract OCR"""
        if not TESSERACT_AVAILABLE:
            return ""
        
        try:
            # Configure Tesseract for license plates
            config = (
                '--oem 3 --psm 7 '
                '-c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            )
            
            text = pytesseract.image_to_string(image, config=config)
            return text.strip()
            
        except Exception as e:
            print(f"Tesseract extraction error: {e}")
            return ""
    
    def _clean_plate_text(self, text: str) -> str:
        """
        Clean and normalize extracted plate text
        
        Indian plate format: SS NN X/XX NNNN
        - SS: State code (2 letters)
        - NN: District code (2 digits)
        - X/XX: Series (1-2 letters)
        - NNNN: Number (4 digits)
        
        Examples: KA01AB1234, MH12DE5678, DL3CAB1234
        """
        if not text:
            return ""
        
        # Remove all whitespace and convert to uppercase
        cleaned = re.sub(r'\s+', '', text.upper())
        
        # Remove any non-alphanumeric characters
        cleaned = re.sub(r'[^A-Z0-9]', '', cleaned)
        
        # Common OCR corrections
        corrections = {
            'O': '0',  # O often misread as 0 in digit positions
            'I': '1',  # I often misread as 1
            'S': '5',  # S sometimes misread as 5
            'B': '8',  # B sometimes misread as 8
        }
        
        # Apply corrections based on position
        # First 2 chars should be letters (state code)
        # Chars 3-4 should be digits (district code)
        
        result = list(cleaned)
        for i, char in enumerate(result):
            if i < 2:  # State code - should be letters
                if char == '0':
                    result[i] = 'O'
                elif char == '1':
                    result[i] = 'I'
            elif 2 <= i < 4:  # District code - should be digits
                if char in corrections:
                    result[i] = corrections[char]
        
        return ''.join(result)
    
    def extract_with_confidence(self, image: np.ndarray) -> Tuple[str, float]:
        """
        Extract text with confidence score
        
        Returns:
            Tuple of (text, confidence)
        """
        if self.reader is None:
            text = self._extract_with_tesseract(self._preprocess_for_ocr(image))
            return (text, 0.5)  # Lower confidence for Tesseract
        
        try:
            processed = self._preprocess_for_ocr(image)
            results = self.reader.readtext(
                processed,
                detail=1,
                paragraph=False,
                allowlist='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            )
            
            if not results:
                return ("", 0.0)
            
            # Calculate average confidence
            texts = []
            confidences = []
            
            for bbox, text, conf in results:
                texts.append(text)
                confidences.append(conf)
            
            combined_text = ''.join(texts)
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            
            cleaned_text = self._clean_plate_text(combined_text)
            
            return (cleaned_text, avg_confidence)
            
        except Exception as e:
            print(f"OCR with confidence error: {e}")
            return ("", 0.0)


# Test
if __name__ == '__main__':
    engine = OCREngine()
    print("OCR Engine initialized")
    print(f"EasyOCR available: {EASYOCR_AVAILABLE}")
    print(f"Tesseract available: {TESSERACT_AVAILABLE}")

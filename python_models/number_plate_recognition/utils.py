"""
Utility functions for Number Plate Recognition
"""

import cv2
import numpy as np
import re
from typing import Tuple, Optional


def preprocess_image(image: np.ndarray) -> np.ndarray:
    """
    Preprocess image for plate detection
    
    Args:
        image: Input BGR image
        
    Returns:
        Preprocessed image
    """
    if image is None:
        return None
    
    # Create a copy
    processed = image.copy()
    
    # Resize if too large
    max_dimension = 1280
    h, w = processed.shape[:2]
    
    if max(h, w) > max_dimension:
        scale = max_dimension / max(h, w)
        processed = cv2.resize(processed, None, fx=scale, fy=scale)
    
    # Enhance contrast
    lab = cv2.cvtColor(processed, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    # Apply CLAHE to L channel
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    
    # Merge and convert back
    enhanced = cv2.merge([l, a, b])
    processed = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)
    
    return processed


def validate_plate_format(plate_text: str) -> Tuple[Optional[str], bool]:
    """
    Validate and format Indian license plate number
    
    Indian plate formats:
    - Standard: SS NN X NNNN or SS NN XX NNNN
    - Temporary: SS NN T NNNN
    - Electric: SS NN BH NNNN (Bharat series)
    
    Args:
        plate_text: Raw extracted plate text
        
    Returns:
        Tuple of (formatted_plate, is_valid)
    """
    if not plate_text:
        return (None, False)
    
    # Clean the text
    cleaned = re.sub(r'[^A-Z0-9]', '', plate_text.upper())
    
    # Indian state codes
    state_codes = [
        'AN', 'AP', 'AR', 'AS', 'BR', 'CH', 'CG', 'DD', 'DL', 'GA',
        'GJ', 'HP', 'HR', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD', 'MH',
        'ML', 'MN', 'MP', 'MZ', 'NL', 'OD', 'PB', 'PY', 'RJ', 'SK',
        'TN', 'TR', 'TS', 'UK', 'UP', 'WB'
    ]
    
    # Pattern 1: Standard format (e.g., KA01AB1234)
    pattern1 = r'^([A-Z]{2})(\d{2})([A-Z]{1,3})(\d{1,4})$'
    
    # Pattern 2: Bharat series (e.g., KA01BH1234)
    pattern2 = r'^([A-Z]{2})(\d{2})(BH)(\d{4})$'
    
    # Pattern 3: Old format with space variations
    pattern3 = r'^([A-Z]{2})(\d{1,2})([A-Z]{1,2})(\d{1,4})$'
    
    for pattern in [pattern1, pattern2, pattern3]:
        match = re.match(pattern, cleaned)
        if match:
            groups = match.groups()
            state = groups[0]
            
            # Validate state code
            if state in state_codes:
                # Format: SS-NN-XX-NNNN
                formatted = f"{groups[0]}{groups[1]}{groups[2]}{groups[3]}"
                return (formatted, True)
    
    # If no pattern matches but has reasonable length, return cleaned text
    if 8 <= len(cleaned) <= 12:
        return (cleaned, False)
    
    return (None, False)


def calculate_plate_angle(contour: np.ndarray) -> float:
    """
    Calculate rotation angle of detected plate contour
    
    Args:
        contour: Plate contour points
        
    Returns:
        Rotation angle in degrees
    """
    if contour is None or len(contour) < 5:
        return 0.0
    
    try:
        rect = cv2.minAreaRect(contour)
        angle = rect[2]
        
        # Normalize angle
        if angle < -45:
            angle = 90 + angle
        
        return angle
    except:
        return 0.0


def deskew_plate(image: np.ndarray, angle: float) -> np.ndarray:
    """
    Deskew/rotate plate image
    
    Args:
        image: Plate image
        angle: Rotation angle
        
    Returns:
        Deskewed image
    """
    if abs(angle) < 1:
        return image
    
    h, w = image.shape[:2]
    center = (w // 2, h // 2)
    
    # Get rotation matrix
    M = cv2.getRotationMatrix2D(center, angle, 1.0)
    
    # Calculate new image size
    cos = np.abs(M[0, 0])
    sin = np.abs(M[0, 1])
    new_w = int((h * sin) + (w * cos))
    new_h = int((h * cos) + (w * sin))
    
    # Adjust transformation matrix
    M[0, 2] += (new_w / 2) - center[0]
    M[1, 2] += (new_h / 2) - center[1]
    
    # Apply rotation
    rotated = cv2.warpAffine(
        image, M, (new_w, new_h),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_REPLICATE
    )
    
    return rotated


def enhance_plate_image(image: np.ndarray) -> np.ndarray:
    """
    Enhance plate image for better OCR
    
    Args:
        image: Plate image
        
    Returns:
        Enhanced image
    """
    if image is None or image.size == 0:
        return image
    
    # Convert to grayscale if needed
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image.copy()
    
    # Remove noise
    denoised = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)
    
    # Sharpen
    kernel = np.array([[-1, -1, -1],
                       [-1,  9, -1],
                       [-1, -1, -1]])
    sharpened = cv2.filter2D(denoised, -1, kernel)
    
    # Increase contrast
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(4, 4))
    enhanced = clahe.apply(sharpened)
    
    return enhanced


def draw_plate_detection(image: np.ndarray, bbox: Tuple[int, int, int, int],
                         plate_text: str, confidence: float) -> np.ndarray:
    """
    Draw detection visualization on image
    
    Args:
        image: Original image
        bbox: Bounding box (x1, y1, x2, y2)
        plate_text: Detected plate text
        confidence: Detection confidence
        
    Returns:
        Image with visualization
    """
    result = image.copy()
    x1, y1, x2, y2 = bbox
    
    # Draw bounding box
    color = (0, 255, 0) if confidence > 0.7 else (0, 255, 255)
    cv2.rectangle(result, (x1, y1), (x2, y2), color, 2)
    
    # Draw label background
    label = f"{plate_text} ({confidence:.2f})"
    (label_w, label_h), baseline = cv2.getTextSize(
        label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2
    )
    
    cv2.rectangle(
        result,
        (x1, y1 - label_h - 10),
        (x1 + label_w + 10, y1),
        color, -1
    )
    
    # Draw label text
    cv2.putText(
        result, label,
        (x1 + 5, y1 - 5),
        cv2.FONT_HERSHEY_SIMPLEX, 0.6,
        (0, 0, 0), 2
    )
    
    return result


def is_valid_plate_region(width: int, height: int, 
                          image_width: int, image_height: int) -> bool:
    """
    Check if detected region has valid plate dimensions
    
    Args:
        width, height: Detected region dimensions
        image_width, image_height: Original image dimensions
        
    Returns:
        True if region could be a valid plate
    """
    # Minimum size constraints
    if width < 60 or height < 15:
        return False
    
    # Maximum size (plate shouldn't be larger than 30% of image)
    if width > image_width * 0.5 or height > image_height * 0.3:
        return False
    
    # Aspect ratio check (Indian plates: ~4.7:1 or ~2:1)
    aspect_ratio = width / height if height > 0 else 0
    
    if not (1.5 < aspect_ratio < 7.0):
        return False
    
    return True

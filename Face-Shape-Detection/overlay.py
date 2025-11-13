# overlay.py

import cv2
import numpy as np
import os

def load_glasses(path):
    """Load a glasses image with automatic background removal and handle removal"""
    try:
        if not os.path.exists(path):
            raise FileNotFoundError(f"Glasses image not found: {path}")
        
        img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
        if img is None:
            raise ValueError(f"Could not load image: {path}")
        
        print(f"✓ Successfully loaded frame: {os.path.basename(path)}")
        
        # If image has background (3 channels), remove it
        if img.shape[2] == 3:
            img = remove_background_simple(img)
        else:
            # For images with alpha channel, just clean it up
            img = clean_existing_alpha(img)
        
        # Remove handles from the glasses
        img = remove_handles_simple(img)
        
        return img
    except Exception as e:
        print(f"✗ Error loading frame {path}: {e}")
        raise

def remove_background_simple(img):
    """Simple and reliable background removal"""
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Create a mask using threshold
    _, mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)
    
    # Clean up the mask
    kernel = np.ones((3,3), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    
    # Create RGBA image
    result = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
    result[:, :, 3] = mask
    
    return result

def clean_existing_alpha(img):
    """Clean up existing alpha channel"""
    alpha = img[:, :, 3]
    
    # Remove very transparent pixels (background)
    _, clean_alpha = cv2.threshold(alpha, 10, 255, cv2.THRESH_BINARY)
    
    # Clean up the mask
    kernel = np.ones((2,2), np.uint8)
    clean_alpha = cv2.morphologyEx(clean_alpha, cv2.MORPH_OPEN, kernel)
    
    img[:, :, 3] = clean_alpha
    return img

def remove_handles_simple(img):
    """Remove handles by keeping only the main central component"""
    alpha = img[:, :, 3]
    
    # Find connected components
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(alpha, connectivity=8)
    
    if num_labels < 2:
        return img  # No components found
    
    # Find the largest component (main glasses frame)
    largest_component = 1
    max_area = stats[1, cv2.CC_STAT_AREA]
    for i in range(2, num_labels):
        if stats[i, cv2.CC_STAT_AREA] > max_area:
            max_area = stats[i, cv2.CC_STAT_AREA]
            largest_component = i
    
    # Create mask with only the largest component
    main_mask = (labels == largest_component).astype(np.uint8) * 255
    
    # Apply the mask
    result = img.copy()
    result[:, :, 3] = main_mask
    
    return result

def get_head_pose(landmarks):
    """
    Estimate head pose from facial landmarks.
    Returns: yaw (left/right), pitch (up/down), roll (tilt)
    """
    left_eyes = landmarks[33]     # Right eye
    right_eyes = landmarks[263]   # Left eye
    nose_tip = landmarks[1]       # Nose tip
    nose_bridge_top = landmarks[6]  # Top of nose bridge

    # Vector from left eye to right eye → horizontal alignment
    eye_vector = np.array([right_eyes[0] - left_eyes[0], right_eyes[1] - left_eyes[1]])
    yaw = np.degrees(np.arctan2(eye_vector[1], eye_vector[0]))

    # Vector from nose tip to nose bridge → vertical tilt
    nose_vector = np.array([nose_bridge_top[0] - nose_tip[0], nose_bridge_top[1] - nose_tip[1]])
    pitch = np.degrees(np.arctan2(nose_vector[1], nose_vector[0]))

    # Roll: difference in eye height
    roll = (left_eyes[1] - right_eyes[1]) * 50  # Scale factor

    return yaw, pitch, roll

def overlay_glasses_with_handles(frame, landmarks, glasses_img, scale_factor=1.0, debug=False):
    """
    Perfect overlay glasses - using the original working code
    """
    h, w = frame.shape[:2]

    def to_pixel(lm):
        return np.array([int(lm[0] * w), int(lm[1] * h)])

    # Key landmarks - EXACTLY like original working code
    left_eyes = to_pixel(landmarks[33])
    right_eyes = to_pixel(landmarks[263])
    nose_bridge = to_pixel(landmarks[6])

    # Compute scale based on eye distance - EXACTLY like original
    eye_distance = np.linalg.norm(left_eyes - right_eyes)
    scale_factor_total = 1.7 * scale_factor  # Apply size scaling to original scale
    new_width = int(eye_distance * scale_factor_total)
    scale_ratio = new_width / glasses_img.shape[1]
    new_height = int(glasses_img.shape[0] * scale_ratio)

    # Resize glasses
    resized_glasses = cv2.resize(glasses_img, (new_width, new_height), interpolation=cv2.INTER_AREA)

    # Soften alpha channel before rotation - EXACTLY like original
    alpha_channel = resized_glasses[:, :, 3].astype(np.float32) / 255.0
    alpha_channel = cv2.GaussianBlur(alpha_channel, (5, 5), 0)
    resized_glasses[:, :, 3] = (alpha_channel * 255).astype(np.uint8)

    # Get head pose
    yaw, pitch, roll = get_head_pose(landmarks)

    # Rotate around center - EXACTLY like original
    center = (new_width // 2, new_height // 2)
    rotation_matrix = cv2.getRotationMatrix2D(center, -yaw, 1.0)
    rotated_glasses = cv2.warpAffine(resized_glasses, rotation_matrix, (new_width, new_height),
                                     flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_TRANSPARENT)

    # Position: center at nose bridge - EXACTLY like original
    pos_x = nose_bridge[0] - new_width // 2
    pos_y = nose_bridge[1] - new_height // 2

    # Bounds check - EXACTLY like original
    glass_h, glass_w = rotated_glasses.shape[:2]
    x1 = max(pos_x, 0)
    y1 = max(pos_y, 0)
    x2 = min(pos_x + glass_w, w)
    y2 = min(pos_y + glass_h, h)

    gx1 = x1 - pos_x
    gy1 = y1 - pos_y
    gx2 = gx1 + (x2 - x1)
    gy2 = gy1 + (y2 - y1)

    if x2 <= x1 or y2 <= y1:
        return frame

    roi_frame = frame[y1:y2, x1:x2]
    glass_roi = rotated_glasses[gy1:gy2, gx1:gx2]

    # Smooth alpha for better blending - EXACTLY like original
    alpha = glass_roi[:, :, 3] / 255.0
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)

    # Perfect blending - EXACTLY like original
    for c in range(3):
        roi_frame[:, :, c] = alpha * glass_roi[:, :, c] + (1 - alpha) * roi_frame[:, :, c]

    frame[y1:y2, x1:x2] = roi_frame

    return frame
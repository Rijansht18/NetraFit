from flask import Flask, request, render_template, Response, url_for, send_from_directory, jsonify
from flask_cors import CORS
import cv2
import numpy as np
import pickle
import os
import warnings
from werkzeug.utils import secure_filename
import mediapipe as mp
from mediapipe import solutions
from mediapipe.framework.formats import landmark_pb2
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import time
import base64
import datetime

from overlay import overlay_glasses_with_handles, load_glasses, load_glasses_from_bytes
import requests

# Backend configuration for remote frames - UPDATED TO YOUR HOSTED BACKEND
BACKEND_URL = 'https://ar-eyewear-try-on-backend-1.onrender.com'

# -------------------- Setup --------------------
warnings.filterwarnings("ignore", category=UserWarning, module='google.protobuf')

app = Flask(__name__, template_folder='templates')
# Enable CORS for all routes with more permissive settings
CORS(app, resources={r"/*": {"origins": "*"}})

app.config['UPLOAD_FOLDER'] = 'uploads/'
app.config['ALLOWED_EXTENSIONS'] = {'jpg', 'jpeg', 'png'}

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Remove any legacy local frames images — local storage is deprecated.
LEGACY_FRAMES_DIR = 'frames'
if os.path.exists(LEGACY_FRAMES_DIR):
    try:
        for fname in os.listdir(LEGACY_FRAMES_DIR):
            if fname.lower().endswith(('.png', '.jpg', '.jpeg')):
                path = os.path.join(LEGACY_FRAMES_DIR, fname)
                try:
                    os.remove(path)
                    print(f"Removed legacy frame image: {path}")
                except Exception as e:
                    print(f"Warning: could not remove legacy frame {path}: {e}")
    except Exception as e:
        print(f"Warning: error while cleaning legacy frames folder: {e}")

# -------------------- MediaPipe & Model --------------------
# Initialize MediaPipe Face Landmarker
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

# Load face shape model
try:
    with open('Best_RandomForest.pkl', 'rb') as f:
        face_shape_model = pickle.load(f)
    print("✓ Face shape model loaded successfully")
except Exception as e:
    print(f"✗ Error loading face shape model: {e}")
    face_shape_model = None

# -------------------- Frame Size Options --------------------
FRAME_SIZES = {
    'small': {'label': 'Small', 'scale_factor': 0.8},
    'medium': {'label': 'Medium', 'scale_factor': 1.0},
    'large': {'label': 'Large', 'scale_factor': 1.2}
}

# -------------------- Face Shape to Frame Recommendations --------------------
FACE_SHAPE_RECOMMENDATIONS = {
    "Heart": ["Aviator", "Round", "Wayfarer", "Butterfly", "Semi-rimless"],
    "Oval": ["Rectangle", "Square", "Wayfarer", "Aviator", "Geometric"],
    "Round": ["Rectangle", "Square", "Wayfarer", "Cat-eye", "Browline"],
    "Square": ["Round", "Oval", "Aviator", "Butterfly", "Rimless"]
}

# NOTE: IMAGE_CHART removed — recommendations now compare frame['shape']

# -------------------- Distance Calibration --------------------
STANDARD_FACE_WIDTH_50CM = 0.25
OPTIMAL_DISTANCE_MIN = 40
OPTIMAL_DISTANCE_MAX = 70
TARGET_DISTANCE = 50  # Target 50cm for analysis

def estimate_distance(landmarks):
    """Estimate distance from camera based on face width"""
    try:
        left_cheek = landmarks[234]
        right_cheek = landmarks[454]
        face_width = np.linalg.norm(np.array(left_cheek) - np.array(right_cheek))
        estimated_distance = (STANDARD_FACE_WIDTH_50CM / face_width) * 50
        return estimated_distance
    except Exception as e:
        print(f"Distance estimation error: {e}")
        return 0

def get_distance_status(distance):
    """Get status message based on distance"""
    if distance < OPTIMAL_DISTANCE_MIN:
        return "too_close", f"Move back ({distance:.1f}cm)"
    elif distance > OPTIMAL_DISTANCE_MAX:
        return "too_far", f"Move closer ({distance:.1f}cm)"
    else:
        return "optimal", f"Good distance ({distance:.1f}cm)"

# -------------------- Frame Analysis --------------------
def analyze_frame_shape(frame_path):
    """
    Analyze frame image to determine its shape/style
    Returns: frame shape category
    """
    try:
        img = cv2.imread(frame_path, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return "Unknown"

        # Get image dimensions
        height, width = img.shape

        # Calculate aspect ratio
        aspect_ratio = width / height if height > 0 else 0

        # Create a mask to analyze frame shape
        _, binary = cv2.threshold(img, 240, 255, cv2.THRESH_BINARY_INV)

        # Find contours
        contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            return "Unknown"

        # Get the largest contour (main frame)
        largest_contour = max(contours, key=cv2.contourArea)

        # Get bounding rectangle
        x, y, w, h = cv2.boundingRect(largest_contour)

        # Calculate frame properties
        frame_aspect_ratio = w / h if h > 0 else 0
        area = cv2.contourArea(largest_contour)
        perimeter = cv2.arcLength(largest_contour, True)

        # Circularity calculation
        if perimeter > 0:
            circularity = 4 * np.pi * area / (perimeter * perimeter)
        else:
            circularity = 0

        # Shape classification based on properties
        if circularity > 0.8:
            return "Round"
        elif frame_aspect_ratio > 1.3:
            return "Rectangle"
        elif frame_aspect_ratio < 0.8:
            return "Aviator"
        elif 0.9 <= frame_aspect_ratio <= 1.1:
            return "Square"
        else:
            return "Geometric"

    except Exception as e:
        print(f"Error analyzing frame {frame_path}: {e}")
        return "Unknown"

# We no longer analyze or store frames locally. All frames come from backend.
frame_shapes_map = {}

# -------------------- Frame Management --------------------
def get_available_frames():
    """Get list of available glass frames from backend API."""
    try:
        resp = requests.get(f"{BACKEND_URL}/api/frames", timeout=30)
        if resp.ok:
            payload = resp.json()
            frames_data = payload.get('data', [])
            frames = []
            for f in frames_data:
                fid = str(f.get('_id', ''))
                name = f.get('name', fid)
                shape = f.get('shape', 'Unknown')
                
                # Get overlay image URL
                overlay_image_data = f.get('overlayImage', {})
                if overlay_image_data:
                    overlay_url = f"{BACKEND_URL}/api/frames/images/{fid}/overlay"
                else:
                    overlay_url = None
                
                # Get display images
                image_urls = []
                images_data = f.get('images', [])
                for idx, img_data in enumerate(images_data):
                    image_urls.append(f"{BACKEND_URL}/api/frames/images/{fid}/{idx}")
                
                frames.append({
                    'id': fid,
                    'filename': fid,  # Use ID as filename for compatibility
                    'name': name,
                    'shape': shape,
                    'overlay_url': overlay_url,
                    'image_urls': image_urls,
                    'remote': True,
                    'brand': f.get('brand', ''),
                    'price': f.get('price', 0),
                    'description': f.get('description', ''),
                    'quantity': f.get('quantity', 0),
                    'type': f.get('type', ''),
                    'size': f.get('size', ''),
                    'colors': f.get('colors', [])
                })
            print(f"✓ Successfully fetched {len(frames)} frames from backend")
            return frames
        else:
            print(f"✗ Backend returned error: {resp.status_code} - {resp.text}")
    except requests.exceptions.Timeout:
        print(f"✗ Timeout fetching frames from {BACKEND_URL}")
    except requests.exceptions.ConnectionError:
        print(f"✗ Connection error to {BACKEND_URL}")
    except Exception as e:
        print(f"✗ Error fetching frames from {BACKEND_URL}: {e}")

    return []


def find_frame_entry(identifier):
    """Find a frame entry in current available frames by filename, id or name."""
    entries = get_available_frames()
    for e in entries:
        if identifier == e.get('filename') or identifier == e.get('id') or identifier == e.get('name'):
            return e
    return None


def load_glasses_from_url(url, filename=None):
    """Download overlay image from URL and load it into an RGBA image using overlay helper."""
    try:
        if not url:
            raise ValueError("No URL provided")
            
        print(f"Loading glasses from URL: {url}")
        
        # Increase timeout for hosted backend
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        data = resp.content
        
        if len(data) == 0:
            raise ValueError("Empty response from server")
            
        print(f"Successfully downloaded {len(data)} bytes for {filename or 'unknown'}")
        return load_glasses_from_bytes(data, filename=filename)
    except requests.exceptions.Timeout:
        print(f"Timeout loading glasses from {url}")
        raise
    except Exception as e:
        print(f"Error fetching overlay image from {url}: {e}")
        raise

def get_recommended_frames(face_shape):
    """Return frames whose `shape` matches the recommended shapes for the detected face shape.

    The backend stores frame.shape values in a lowercase/underscore format
    (for example: 'round', 'rectangle', 'cate_eye', 'wayfarer'). This function
    normalizes both the recommended names and the backend values so they can
    be compared reliably. Only frames that match the recommended shapes are
    returned (up to 5), ordered by recommendation priority.
    """
    recommended_shapes = FACE_SHAPE_RECOMMENDATIONS.get(face_shape, [])
    if not recommended_shapes:
        return []

    def _normalize_name(name: str) -> str:
        if not name:
            return ''
        n = name.strip().lower()
        # Normalize common separators
        n = n.replace('-', '_').replace(' ', '_')
        # Map common display names to backend enum values
        mappings = {
            'cat_eye': 'cate_eye',
            'cat-eye': 'cate_eye',
            'cateye': 'cate_eye',
            'cateye': 'cate_eye',
            'semi_rimless': 'semi_rimless',
            'semi-rimless': 'semi_rimless',
            'rimless': 'rimless',
            'butterfly': 'butterfly'
        }
        if n in mappings:
            return mappings[n]
        return n

    norm_recs = [_normalize_name(s) for s in recommended_shapes]

    all_frames = get_available_frames()
    matched = []

    for frame in all_frames:
        frame_shape_raw = frame.get('shape') or ''
        frame_shape_norm = _normalize_name(frame_shape_raw)
        if frame_shape_norm in norm_recs:
            item = frame.copy()
            item['matched'] = True
            item['matched_shape'] = frame_shape_raw
            item['_match_priority'] = norm_recs.index(frame_shape_norm)
            matched.append(item)

    # Order by priority (according to the recommendation list)
    matched.sort(key=lambda x: x.get('_match_priority', 999))
    for item in matched:
        item.pop('_match_priority', None)

    return matched[:5]

# Global variables for real-time
current_glasses = None
current_frame_size = 'medium'

# Load default glasses (try remote overlay first)
available_frames = get_available_frames()
if available_frames:
    try:
        first = available_frames[0]
        # Only support remote overlays now
        if first.get('remote') and first.get('overlay_url'):
            try:
                current_glasses = load_glasses_from_url(first['overlay_url'], filename=first.get('name'))
            except Exception as e:
                print(f"✗ Error loading default frame overlay: {e}")
                current_glasses = None
            print(f"✓ Loaded default remote frame: {first.get('name')} (Shape: {first.get('shape')})")
        else:
            print(f"⚠ Default frame '{first.get('name')}' is not remote — skipped (local storage removed)")
    except Exception as e:
        print(f"✗ Error loading default frame: {e}")
        current_glasses = None
else:
    print("⚠ Warning: No frames found (remote or local)!")

# -------------------- Face Shape Detection --------------------
def distance_3d(p1, p2):
    return np.linalg.norm(np.array(p1) - np.array(p2))

def calculate_face_features(landmarks):
    """Original face features calculation that matches the trained model (9 features)"""
    # Landmark indices
    idx = {
        'forehead': 10,
        'chin': 152,
        'left_cheek': 234,
        'right_cheek': 454,
        'left_eye': 33,
        'right_eye': 263,
        'nose_tip': 1
    }

    # Extract landmark coordinates
    lm = {}
    for name, i in idx.items():
        if i < len(landmarks):
            lm[name] = [landmarks[i].x, landmarks[i].y, landmarks[i].z]
        else:
            # Fallback to default coordinates if index out of range
            lm[name] = [0.5, 0.5, 0]

    features = [
        distance_3d(lm['forehead'], lm['chin']),           # 1. Face height
        distance_3d(lm['left_cheek'], lm['right_cheek']),  # 2. Face width
        distance_3d(lm['left_eye'], lm['right_eye']),      # 3. Eye distance
        distance_3d(lm['nose_tip'], lm['left_eye']),       # 4. Nose to left eye
        distance_3d(lm['nose_tip'], lm['right_eye']),      # 5. Nose to right eye
        distance_3d(lm['chin'], lm['left_cheek']),         # 6. Chin to left cheek
        distance_3d(lm['chin'], lm['right_cheek']),        # 7. Chin to right cheek
        distance_3d(lm['forehead'], lm['left_eye']),       # 8. Forehead to left eye
        distance_3d(lm['forehead'], lm['right_eye'])       # 9. Forehead to right eye
    ]
    return np.array(features)

def get_face_shape_label(label):
    shapes = ["Heart", "Oval", "Round", "Square"]
    if 0 <= label < len(shapes):
        return shapes[label]
    return "Unknown"

def draw_landmarks_on_image(rgb_image, detection_result):
    annotated_image = np.copy(rgb_image)
    face_landmarks_list = detection_result.multi_face_landmarks
    if face_landmarks_list:
        for face_landmarks in face_landmarks_list:
            mp_drawing.draw_landmarks(
                image=annotated_image,
                landmark_list=face_landmarks,
                connections=mp_face_mesh.FACEMESH_TESSELATION,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_tesselation_style()
            )
    return annotated_image

# -------------------- Advanced Face Shape Stabilizer --------------------
class FaceShapeAnalyzer:
    def __init__(self, analysis_duration=3.0, stability_threshold=0.8):
        self.analysis_duration = analysis_duration
        self.stability_threshold = stability_threshold
        self.analysis_start_time = None
        self.detected_shape = None
        self.final_shape = None
        self.analysis_complete = False
        self.shape_history = []
        self.optimal_distance_count = 0

    def start_analysis(self):
        """Start the 3-second analysis period"""
        self.analysis_start_time = time.time()
        self.analysis_complete = False
        self.final_shape = None
        self.shape_history = []
        self.optimal_distance_count = 0
        print("Starting face shape analysis...")

    def update_analysis(self, shape, distance_status):
        """Update analysis with current shape and distance status"""
        current_time = time.time()

        if self.analysis_start_time is None:
            return None

        elapsed = current_time - self.analysis_start_time
        remaining = max(0, self.analysis_duration - elapsed)

        # Only count shapes when at optimal distance
        if distance_status == "optimal":
            self.optimal_distance_count += 1
            self.shape_history.append(shape)

            # Calculate stability
            if len(self.shape_history) > 5:
                recent_shapes = self.shape_history[-5:]
                most_common = max(set(recent_shapes), key=recent_shapes.count)
                confidence = recent_shapes.count(most_common) / len(recent_shapes)

                if confidence >= self.stability_threshold:
                    self.detected_shape = most_common

        # Check if analysis period is complete
        if elapsed >= self.analysis_duration:
            if self.detected_shape and self.optimal_distance_count >= 10:
                self.final_shape = self.detected_shape
                self.analysis_complete = True
                print(f"Analysis complete! Detected shape: {self.final_shape}")
            else:
                # Not enough stable data, restart analysis
                self.start_analysis()

        return remaining

    def get_analysis_progress(self):
        """Get current analysis progress"""
        if self.analysis_start_time is None:
            return 0, 0

        elapsed = time.time() - self.analysis_start_time
        progress = min(100, (elapsed / self.analysis_duration) * 100)
        remaining = max(0, self.analysis_duration - elapsed)

        return progress, remaining

    def reset(self):
        """Reset the analyzer"""
        self.analysis_start_time = None
        self.detected_shape = None
        self.final_shape = None
        self.analysis_complete = False
        self.shape_history = []
        self.optimal_distance_count = 0

# -------------------- CLIENT CAMERA ENDPOINTS --------------------

# Add this route BEFORE your other routes
@app.route('/api/proxy/<path:subpath>', methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
def proxy_to_backend(subpath):
    """Proxy API requests to Node.js backend"""
    try:
        # Build the target URL
        node_backend = 'https://ar-eyewear-try-on-backend-1.onrender.com'
        url = f"{node_backend}/api/{subpath}"
        
        # Forward headers (remove Host header to avoid issues)
        headers = {key: value for key, value in request.headers if key.lower() != 'host'}
        
        # Add CORS headers for cross-origin requests
        headers['Origin'] = request.host_url.rstrip('/')
        
        # Handle different request methods
        if request.method == 'GET':
            resp = requests.get(url, params=request.args, headers=headers, timeout=30)
        elif request.method == 'POST':
            # Handle multipart/form-data (file uploads)
            if request.content_type and 'multipart/form-data' in request.content_type:
                files = request.files
                data = request.form.to_dict()
                resp = requests.post(url, files=files, data=data, headers=headers, timeout=30)
            else:
                # Handle JSON or form data
                data = request.get_data()
                resp = requests.post(url, data=data, headers=headers, 
                                   json=request.json if request.is_json else None, timeout=30)
        elif request.method == 'PUT':
            if request.content_type and 'multipart/form-data' in request.content_type:
                files = request.files
                data = request.form.to_dict()
                resp = requests.put(url, files=files, data=data, headers=headers, timeout=30)
            else:
                data = request.get_data()
                resp = requests.put(url, data=data, headers=headers,
                                  json=request.json if request.is_json else None, timeout=30)
        elif request.method == 'DELETE':
            resp = requests.delete(url, headers=headers, timeout=30)
        elif request.method == 'OPTIONS':
            # Handle CORS preflight
            response = Response(status=200)
            response.headers.add('Access-Control-Allow-Origin', '*')
            response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
            response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
            return response
        else:
            return jsonify({'error': 'Method not allowed'}), 405
        
        # Return the response with CORS headers
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        response_headers = [(name, value) for (name, value) in resp.raw.headers.items() 
                          if name.lower() not in excluded_headers]
        
        # Add CORS headers
        response_headers.append(('Access-Control-Allow-Origin', '*'))
        
        response = Response(resp.content, resp.status_code, response_headers)
        return response
        
    except requests.exceptions.Timeout:
        print(f"Proxy timeout for {subpath}")
        return jsonify({'error': 'Backend request timeout'}), 504
    except requests.exceptions.RequestException as e:
        print(f"Proxy error for {subpath}: {e}")
        return jsonify({'error': f'Backend connection failed: {str(e)}'}), 500
    except Exception as e:
        print(f"Unexpected proxy error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/client_camera')
def client_camera():
    """Client camera version - uses client's camera instead of server camera"""
    frames = get_available_frames()
    return render_template('client_camera.html', frames=frames, frame_sizes=FRAME_SIZES)

@app.route('/api/process_frame', methods=['POST'])
def api_process_frame():
    """Process a single frame from client camera for real-time try-on"""
    try:
        # Get frame data from request
        data = request.json
        if not data or 'image' not in data:
            return jsonify({'success': False, 'error': 'No image data'})

        # Decode base64 image
        try:
            image_data = data['image'].split(',')[1]  # Remove data:image/jpeg;base64,
        except:
            image_data = data['image']  # If no prefix, use as is

        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return jsonify({'success': False, 'error': 'Could not decode image'})

        # Resize frame if too large for faster processing (max width 640px)
        height, width = frame.shape[:2]
        if width > 640:
            scale = 640 / width
            new_width = 640
            new_height = int(height * scale)
            frame = cv2.resize(frame, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
            print(f"Resized frame from {width}x{height} to {new_width}x{new_height} for faster processing")

        # Get frame and size from request
        frame_filename = data.get('frame', '')
        size_key = data.get('size', 'medium')

        # Load selected glasses if frame is specified (support remote frames)
        selected_glasses = None
        if frame_filename:
            entry = find_frame_entry(frame_filename)
            if not entry or not entry.get('remote') or not entry.get('overlay_url'):
                return jsonify({'success': False, 'error': 'Frame not available'})
            try:
                selected_glasses = load_glasses_from_url(entry['overlay_url'], filename=entry.get('name'))
                print(f"Loaded remote frame: {frame_filename}")
            except Exception as e:
                print(f"Error loading remote frame {frame_filename}: {e}")
                return jsonify({'success': False, 'error': f'Error loading frame: {str(e)}'})

        # Process frame with MediaPipe
        with mp_face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5) as face_mesh:

            # Flip frame horizontally for mirror effect
            frame = cv2.flip(frame, 1)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb_frame)

            output_frame = frame.copy()
            face_shape = "Unknown"
            distance_message = "No face detected"
            distance_status = "unknown"

            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0].landmark

                # Convert landmarks to array format
                landmarks_array = []
                for lm in landmarks:
                    landmarks_array.append([lm.x, lm.y, lm.z])
                landmarks_array = np.array(landmarks_array)

                # Estimate distance
                try:
                    distance = estimate_distance(landmarks_array)
                    distance_status, distance_message = get_distance_status(distance)
                except Exception as e:
                    print(f"Distance estimation error: {e}")
                    distance_message = "Distance calculation failed"
                    distance_status = "error"

                # Detect face shape
                if face_shape_model is not None:
                    try:
                        features = calculate_face_features(landmarks)
                        label = face_shape_model.predict([features])[0]
                        face_shape = get_face_shape_label(label)
                    except Exception as e:
                        print(f"Face shape prediction error: {e}")
                        face_shape = "Unknown"

                # Overlay glasses if available
                if selected_glasses is not None:
                    scale_factor = FRAME_SIZES.get(size_key, FRAME_SIZES['medium'])['scale_factor']
                    try:
                        output_frame = overlay_glasses_with_handles(
                            output_frame, landmarks_array, selected_glasses,
                            scale_factor=scale_factor
                        )
                        print(f"Successfully overlayed glasses: {frame_filename}")
                    except Exception as e:
                        print(f"Glasses overlay error: {e}")

            # Flip back for output (normal orientation)
            output_frame = cv2.flip(output_frame, 1)

            # Encode output frame to base64 with lower quality for faster transfer
            _, buffer = cv2.imencode('.jpg', output_frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            encoded_image = base64.b64encode(buffer).decode('utf-8')
            image_url = f"data:image/jpeg;base64,{encoded_image}"

            return jsonify({
                'success': True,
                'processed_image': image_url,
                'face_shape': face_shape,
                'distance_message': distance_message,
                'distance_status': distance_status
            })

    except Exception as e:
        print(f"Frame processing error: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/start_realtime', methods=['POST'])
def api_start_realtime():
    """Initialize real-time session"""
    return jsonify({'success': True, 'message': 'Real-time session started'})

@app.route('/api/stop_realtime', methods=['POST'])
def api_stop_realtime():
    """Clean up real-time session"""
    return jsonify({'success': True, 'message': 'Real-time session stopped'})

@app.route('/api/frames', methods=['GET'])
def api_get_frames():
    """API endpoint to get all available frames"""
    frames = get_available_frames()
    return jsonify({'success': True, 'frames': frames})

@app.route('/api/recommendations/<face_shape>', methods=['GET'])
def api_get_recommendations(face_shape):
    """API endpoint to get frame recommendations for face shape"""
    recommended_frames = get_recommended_frames(face_shape)
    return jsonify({
        'success': True,
        'face_shape': face_shape,
        'recommended_frames': recommended_frames
    })


# -------------------- NEW API COMPATIBILITY ENDPOINTS --------------------
@app.route('/api/analyze_face', methods=['POST'])
def api_analyze_face():
    """API endpoint to analyze an uploaded face image and return face shape (JSON)."""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file uploaded'})

        file = request.files['file']
        if file.filename == '' or not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file'})

        file_bytes = file.read()
        nparr = np.frombuffer(file_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({'success': False, 'error': 'Could not decode image'})

        # Process image with MediaPipe Face Mesh (static mode)
        with mp_face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5) as face_mesh:

            rgb_image = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb_image)

            if not results.multi_face_landmarks:
                return jsonify({'success': False, 'error': 'No face detected'})

            landmarks = results.multi_face_landmarks[0].landmark
            landmarks_array = []
            for lm in landmarks:
                landmarks_array.append([lm.x, lm.y, lm.z])
            landmarks_array = np.array(landmarks_array)

            if face_shape_model is None:
                return jsonify({'success': False, 'error': 'Face shape model not available'})

            try:
                features = calculate_face_features(landmarks)
                label = face_shape_model.predict([features])[0]
                face_shape = get_face_shape_label(label)
            except Exception as e:
                return jsonify({'success': False, 'error': f'Prediction error: {e}'})

            return jsonify({'success': True, 'face_shape': face_shape})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/try_frame', methods=['POST'])
def api_try_frame():
    """API endpoint compatible with the Flutter client: accepts multipart file + fields and returns JSON with processed image (data URI) and metadata."""
    try:
        # Validate file
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file uploaded'})

        file = request.files['file']
        if file.filename == '' or not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file'})

        # Read image into memory
        file_bytes = file.read()
        nparr = np.frombuffer(file_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({'success': False, 'error': 'Could not decode image'})

        frame_filename = request.form.get('frame', '')
        size_key = request.form.get('size', 'medium')

        # Load selected glasses if provided — only remote frames supported
        selected_glasses = None
        if frame_filename:
            entry = find_frame_entry(frame_filename)
            if not entry or not entry.get('remote') or not entry.get('overlay_url'):
                return jsonify({'success': False, 'error': 'Frame not available'})
            try:
                selected_glasses = load_glasses_from_url(entry['overlay_url'], filename=entry.get('name'))
            except Exception as e:
                return jsonify({'success': False, 'error': f'Error loading frame: {e}'})

        # Use MediaPipe to detect landmarks (static image mode)
        with mp_face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5) as face_mesh:

            rgb_image = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb_image)

            output_img = img.copy()
            face_shape = 'Unknown'
            distance_message = 'No face detected'
            distance_status = 'unknown'

            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0].landmark
                landmarks_array = []
                for lm in landmarks:
                    landmarks_array.append([lm.x, lm.y, lm.z])
                landmarks_array = np.array(landmarks_array)

                # Estimate distance
                try:
                    distance = estimate_distance(landmarks_array)
                    distance_status, distance_message = get_distance_status(distance)
                except Exception as e:
                    distance_message = 'Distance calc failed'
                    distance_status = 'error'

                # Predict face shape
                if face_shape_model is not None:
                    try:
                        features = calculate_face_features(landmarks)
                        label = face_shape_model.predict([features])[0]
                        face_shape = get_face_shape_label(label)
                    except Exception as e:
                        face_shape = 'Unknown'

                # Overlay glasses if provided
                if selected_glasses is not None:
                    scale_factor = FRAME_SIZES.get(size_key, FRAME_SIZES['medium'])['scale_factor']
                    try:
                        output_img = overlay_glasses_with_handles(
                            output_img, landmarks_array, selected_glasses,
                            scale_factor=scale_factor
                        )
                    except Exception:
                        pass

            # Encode resulting image to base64 data URI
            _, buffer = cv2.imencode('.jpg', output_img, [cv2.IMWRITE_JPEG_QUALITY, 85])
            encoded_image = base64.b64encode(buffer).decode('utf-8')
            image_data_uri = f"data:image/jpeg;base64,{encoded_image}"

            return jsonify({
                'success': True,
                'processed_image': image_data_uri,
                'face_shape': face_shape,
                'distance_message': distance_message,
                'distance_status': distance_status,
                'message': 'Frame processed successfully'
            })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

# -------------------- EXISTING ROUTES (KEPT FOR COMPATIBILITY) --------------------

@app.route('/')
def index():
    frames = get_available_frames()
    return render_template('index.html', frames=frames, frame_sizes=FRAME_SIZES)

@app.route('/upload')
def upload():
    """Simple upload page route"""
    frames = get_available_frames()
    return render_template('upload.html', frames=frames, frame_sizes=FRAME_SIZES)

@app.route('/upload_file', methods=['POST'])
def upload_file():
    """Handle file upload and processing"""
    face_shape = None
    file_url = None
    error = None
    recommended_frames = []
    frames = get_available_frames()

    # Safe default selection
    selected_frame = ''
    selected_size = 'medium'

    if frames:
        selected_frame = request.form.get('frame_select', frames[0]['filename'])
        selected_size = request.form.get('size_select', 'medium')

    if request.method == 'POST':
        if 'file' not in request.files:
            error = "No file part"
        else:
            file = request.files['file']
            if file.filename == '' or not allowed_file(file.filename):
                error = "Invalid file"
            else:
                # Read uploaded file into memory (do not save)
                try:
                    file_bytes = file.read()
                    nparr = np.frombuffer(file_bytes, np.uint8)
                    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                    if img is None:
                        error = "Could not decode the uploaded image"
                        return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                                               error=error, frames=frames, selected_frame=selected_frame,
                                               frame_sizes=FRAME_SIZES, selected_size=selected_size)
                    filename = secure_filename(file.filename)
                except Exception as e:
                    error = f"Could not read uploaded image: {e}"
                    return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                                           error=error, frames=frames, selected_frame=selected_frame,
                                           frame_sizes=FRAME_SIZES, selected_size=selected_size)

                # Load selected glasses (only remote frames supported)
                entry = find_frame_entry(selected_frame)
                if not entry or not entry.get('remote') or not entry.get('overlay_url'):
                    error = "Selected frame not available"
                    return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                                           error=error, frames=frames, selected_frame=selected_frame,
                                           frame_sizes=FRAME_SIZES, selected_size=selected_size)
                try:
                    selected_glasses = load_glasses_from_url(entry['overlay_url'], filename=entry.get('name'))
                except Exception as e:
                    error = f"Error loading selected frame: {str(e)}"
                    return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                                           error=error, frames=frames, selected_frame=selected_frame,
                                           frame_sizes=FRAME_SIZES, selected_size=selected_size)

                # 'img' already contains the decoded uploaded image (in-memory)
                # ensure it's present
                if 'img' not in locals() or img is None:
                    error = "Could not read the uploaded image"
                    return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                                           error=error, frames=frames, selected_frame=selected_frame,
                                           frame_sizes=FRAME_SIZES, selected_size=selected_size)

                # Process image with MediaPipe Face Mesh
                with mp_face_mesh.FaceMesh(
                        static_image_mode=True,
                        max_num_faces=1,
                        refine_landmarks=True,
                        min_detection_confidence=0.5,
                        min_tracking_confidence=0.5) as face_mesh:

                    rgb_image = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                    results = face_mesh.process(rgb_image)

                    if results.multi_face_landmarks:
                        landmarks = results.multi_face_landmarks[0].landmark

                        # Convert landmarks to array format
                        landmarks_array = []
                        for lm in landmarks:
                            landmarks_array.append([lm.x, lm.y, lm.z])
                        landmarks_array = np.array(landmarks_array)

                        if face_shape_model is not None:
                            features = calculate_face_features(landmarks)
                            label = face_shape_model.predict([features])[0]
                            face_shape = get_face_shape_label(label)

                            # Get recommended frames
                            recommended_frames = get_recommended_frames(face_shape)

                            # Get scale factor for selected size
                            scale_factor = FRAME_SIZES[selected_size]['scale_factor']

                            # Overlay glasses
                            overlayed_img = overlay_glasses_with_handles(
                                img.copy(), landmarks_array, selected_glasses,
                                scale_factor=scale_factor
                            )
                            # Encode overlay to base64 data URI for immediate display (no disk write)
                            _, buffer = cv2.imencode('.jpg', overlayed_img, [cv2.IMWRITE_JPEG_QUALITY, 85])
                            encoded_image = base64.b64encode(buffer).decode('utf-8')
                            file_url = f"data:image/jpeg;base64,{encoded_image}"
                        else:
                            error = "Face shape model not available"
                    else:
                        error = "No face detected"

    return render_template('upload.html', face_shape=face_shape, file_url=file_url,
                           error=error, frames=frames, selected_frame=selected_frame,
                           frame_sizes=FRAME_SIZES, selected_size=selected_size,
                           recommended_frames=recommended_frames)

@app.route('/real_time')
def real_time():
    """Legacy real-time page (uses server camera)"""
    frames = get_available_frames()
    return render_template('real_time.html', frames=frames, frame_sizes=FRAME_SIZES)

@app.route('/get_face_shape_recommendations', methods=['POST'])
def get_face_shape_recommendations():
    """API endpoint to get frame recommendations based on detected face shape"""
    data = request.json
    face_shape = data.get('face_shape')

    if not face_shape:
        return jsonify({'success': False, 'error': 'No face shape provided'})

    recommended_frames = get_recommended_frames(face_shape)

    return jsonify({
        'success': True,
        'face_shape': face_shape,
        'recommended_frames': recommended_frames
    })

@app.route('/change_frame', methods=['POST'])
def change_frame():
    """API endpoint to change the current glasses frame"""
    global current_glasses, current_frame_size

    frame_filename = request.json.get('frame')
    size_key = request.json.get('size', 'medium')

    if not frame_filename:
        return jsonify({'success': False, 'error': 'No frame specified'})

    entry = find_frame_entry(frame_filename)
    if not entry or not entry.get('remote') or not entry.get('overlay_url'):
        return jsonify({'success': False, 'error': 'Frame not available'})
    try:
        current_glasses = load_glasses_from_url(entry['overlay_url'], filename=entry.get('name'))
        current_frame_size = size_key
        return jsonify({'success': True, 'message': 'Frame changed successfully'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/get_frames', methods=['GET'])
def get_frames():
    """API endpoint to get list of available frames"""
    frames = get_available_frames()
    return jsonify(frames)

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/frame_image/<filename>')
def frame_image(filename):
    """Local frame images removed — this endpoint is disabled."""
    return jsonify({'success': False, 'error': 'Local frame images have been removed; use backend frames instead.'}), 404

# -------------------- Legacy Server Camera (Optional - Can be removed) --------------------

@app.route('/video_feed')
def video_feed():
    """Legacy server camera feed (optional)"""
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/frame_management/add')
def add_frame():
    """Add new frame page"""
    return render_template('frame_form.html', 
                          edit_mode=False, 
                          frame={},
                          FLASK_BASE_URL=request.host_url.rstrip('/'),
                          USE_PROXY=True,  # Tell template to use proxy
                          NODE_BACKEND_URL=request.host_url.rstrip('/'))  # Use Flask URL for API

@app.route('/frame_management/edit/<frame_id>')
def edit_frame(frame_id):
    """Edit existing frame page"""
    try:
        # Use hosted backend to get frame data
        response = requests.get(f"{BACKEND_URL}/api/frames/{frame_id}", timeout=30)
        
        if not response.ok:
            return "Frame not found", 404
        
        data = response.json()
        
        if not data.get('success'):
            return "Frame not found", 404
        
        frame_data = data.get('data', {})
        
        # Prepare frame object
        frame = {
            'id': frame_id,
            'name': frame_data.get('name', ''),
            'brand': frame_data.get('brand', ''),
            'price': frame_data.get('price', ''),
            'quantity': frame_data.get('quantity', 0),
            'type': frame_data.get('type', ''),
            'shape': frame_data.get('shape', ''),
            'size': frame_data.get('size', ''),
            'description': frame_data.get('description', ''),
            'colors': frame_data.get('colors', []),
            'mainCategory': frame_data.get('mainCategory', {}),
            'subCategory': frame_data.get('subCategory', {})
        }
        
        # Get image URLs from hosted backend
        if frame_data.get('_id'):
            fid = str(frame_data['_id'])
            
            # Product images
            image_urls = []
            if frame_data.get('images'):
                for i in range(len(frame_data['images'])):
                    image_urls.append(f"{BACKEND_URL}/api/frames/images/{fid}/{i}")
            frame['image_urls'] = image_urls
            
            # Overlay image
            if frame_data.get('overlayImage'):
                frame['overlay_url'] = f"{BACKEND_URL}/api/frames/images/{fid}/overlay"
        
        return render_template('frame_form.html', 
                          edit_mode=True, 
                          frame=frame,
                          FLASK_BASE_URL=request.host_url.rstrip('/'),
                          USE_PROXY=True,
                          NODE_BACKEND_URL=request.host_url.rstrip('/'))
    except Exception as e:
        print(f"Error loading frame for edit: {e}")
        return "Error loading frame", 500

def generate_frames():
    """Legacy server camera frame generator"""
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Could not open camera")
        return

    # Initialize MediaPipe Face Mesh for real-time
    face_mesh = mp_face_mesh.FaceMesh(
        static_image_mode=False,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    )

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Error: Could not read frame")
            break

        # Flip frame horizontally for mirror effect
        frame = cv2.flip(frame, 1)

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb_frame)

        display_frame = frame.copy()

        if results.multi_face_landmarks:
            landmarks = results.multi_face_landmarks[0].landmark

            # Convert landmarks to array format
            landmarks_array = []
            for lm in landmarks:
                landmarks_array.append([lm.x, lm.y, lm.z])
            landmarks_array = np.array(landmarks_array)

            # Overlay glasses
            global current_glasses, current_frame_size
            if current_glasses is not None:
                scale_factor = FRAME_SIZES.get(current_frame_size, FRAME_SIZES['medium'])['scale_factor']
                try:
                    display_frame = overlay_glasses_with_handles(
                        display_frame, landmarks_array, current_glasses,
                        scale_factor=scale_factor, debug=False
                    )
                except Exception as e:
                    print(f"Overlay error: {e}")

        # Convert to JPEG for streaming
        ret, buffer = cv2.imencode('.jpg', display_frame)
        if not ret:
            continue

        frame_bytes = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

    # Clean up
    face_mesh.close()
    cap.release()

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

# -------------------- Run --------------------
if __name__ == '__main__':
    print("Starting Flask application...")
    print(f"Using hosted backend: {BACKEND_URL}")
    print(f"Optimal distance range: {OPTIMAL_DISTANCE_MIN}-{OPTIMAL_DISTANCE_MAX} cm")
    print(f"Target analysis distance: {TARGET_DISTANCE} cm")
    print("Available routes:")
    print("  /              - Home page")
    print("  /client_camera - Client camera try-on (RECOMMENDED)")
    print("  /real_time     - Legacy server camera try-on")
    print("  /upload        - Upload image for try-on")
    print("  /api/proxy/*   - Proxy to Node.js backend")
    print("  /frame_management/* - Frame management pages")
    
    # Optional HTTPS support: set environment variables to enable
    # USE_HTTPS=true, SSL_CERT_PATH and SSL_KEY_PATH (paths to .pem files)
    use_https = os.environ.get('USE_HTTPS', 'false').lower() in ('1', 'true', 'yes')
    ssl_cert = os.environ.get('SSL_CERT_PATH', '')
    ssl_key = os.environ.get('SSL_KEY_PATH', '')

    if use_https:
        if ssl_cert and ssl_key and os.path.exists(ssl_cert) and os.path.exists(ssl_key):
            print(f"Running with HTTPS using cert={ssl_cert} key={ssl_key}")
            app.run(debug=True, host='0.0.0.0', port=5000, ssl_context=(ssl_cert, ssl_key))
        else:
            print("USE_HTTPS is set but SSL_CERT_PATH or SSL_KEY_PATH is missing or files do not exist.")
            print("Falling back to HTTP. To enable HTTPS, generate cert/key and set SSL_CERT_PATH and SSL_KEY_PATH.")
            app.run(debug=True, host='0.0.0.0', port=5000)
    else:
        app.run(debug=True, host='0.0.0.0', port=5000)
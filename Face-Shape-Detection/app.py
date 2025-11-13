from flask import Flask, request, render_template, Response, url_for, send_from_directory, jsonify
from flask_cors import CORS  # Add this import
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
import base64  # Add this import
import datetime

from overlay import overlay_glasses_with_handles, load_glasses

# -------------------- Setup --------------------
warnings.filterwarnings("ignore", category=UserWarning, module='google.protobuf')

app = Flask(__name__, template_folder='templates')
CORS(app)  # Enable CORS for all routes

app.config['UPLOAD_FOLDER'] = 'uploads/'
app.config['FRAMES_FOLDER'] = 'frames/'
app.config['ALLOWED_EXTENSIONS'] = {'jpg', 'jpeg', 'png'}

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['FRAMES_FOLDER'], exist_ok=True)

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

# -------------------- Distance Calibration --------------------
STANDARD_FACE_WIDTH_50CM = 0.25
OPTIMAL_DISTANCE_MIN = 40
OPTIMAL_DISTANCE_MAX = 70
TARGET_DISTANCE = 50  # Target 50cm for analysis

def estimate_distance(landmarks):
    """Estimate distance from camera based on face width"""
    left_cheek = landmarks[234]
    right_cheek = landmarks[454]
    face_width = np.linalg.norm(np.array(left_cheek) - np.array(right_cheek))
    estimated_distance = (STANDARD_FACE_WIDTH_50CM / face_width) * 50
    return estimated_distance

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

def get_all_frame_shapes(frames_folder):
    """
    Analyze all frames in the folder and return their shapes
    """
    frame_shapes = {}
    
    if not os.path.exists(frames_folder):
        return frame_shapes
    
    for filename in os.listdir(frames_folder):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            frame_path = os.path.join(frames_folder, filename)
            shape = analyze_frame_shape(frame_path)
            frame_shapes[filename] = shape
            print(f"Frame: {filename} → Shape: {shape}")
    
    return frame_shapes

# Analyze frames at startup
print("Analyzing frame shapes...")
frame_shapes_map = get_all_frame_shapes(app.config['FRAMES_FOLDER'])
print("Frame analysis complete!")

# -------------------- Frame Management --------------------
def get_available_frames():
    """Get list of available glass frames from frames folder with their shapes"""
    frames = []
    frames_folder = app.config['FRAMES_FOLDER']
    if os.path.exists(frames_folder):
        for file in os.listdir(frames_folder):
            if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                frame_name = os.path.splitext(file)[0].replace('_', ' ').title()
                frame_shape = frame_shapes_map.get(file, "Unknown")
                
                frames.append({
                    'filename': file,
                    'path': os.path.join(frames_folder, file),
                    'name': frame_name,
                    'shape': frame_shape
                })
    return frames

def get_recommended_frames(face_shape):
    """Get recommended ACTUAL frame files based on face shape"""
    recommended_shapes = FACE_SHAPE_RECOMMENDATIONS.get(face_shape, [])
    all_frames = get_available_frames()
    
    recommended_frames = []
    
    # First, try exact shape matches
    for frame in all_frames:
        if frame['shape'] in recommended_shapes:
            recommended_frames.append(frame)
    
    # If not enough matches, include similar shapes
    if len(recommended_frames) < 3:
        for frame in all_frames:
            if frame not in recommended_frames and frame['shape'] != "Unknown":
                recommended_frames.append(frame)
    
    # Limit to top 5 recommendations
    return recommended_frames[:5]

# Global variables for real-time
current_glasses = None
current_frame_size = 'medium'

# Load default glasses
available_frames = get_available_frames()
if available_frames:
    try:
        current_glasses = load_glasses(available_frames[0]['path'])
        print(f"✓ Loaded default frame: {available_frames[0]['name']} (Shape: {available_frames[0]['shape']})")
    except Exception as e:
        print(f"✗ Error loading default frame: {e}")
        current_glasses = None
else:
    print("⚠ Warning: No frames found in frames folder!")

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

# -------------------- NEW API ENDPOINTS FOR FLUTTER --------------------

@app.route('/api/analyze_face', methods=['POST'])
def api_analyze_face():
    """API endpoint for face analysis from uploaded image"""
    if 'file' not in request.files:
        return jsonify({'success': False, 'error': 'No file provided'})
    
    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        return jsonify({'success': False, 'error': 'Invalid file'})
    
    # Save uploaded file
    filename = secure_filename(file.filename)
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)
    
    # Process image
    img = cv2.imread(file_path)
    if img is None:
        return jsonify({'success': False, 'error': 'Could not process image'})
    
    # Face detection and analysis
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
        
        # Get face shape
        face_shape = "Unknown"
        if face_shape_model is not None:
            features = calculate_face_features(landmarks)
            label = face_shape_model.predict([features])[0]
            face_shape = get_face_shape_label(label)
        
        # Return analysis results
        return jsonify({
            'success': True,
            'face_shape': face_shape,
            'message': 'Face analysis completed'
        })

@app.route('/api/try_frame', methods=['POST'])
def api_try_frame():
    """API endpoint to try a frame on uploaded image"""
    print(f"📥 API: Received try_frame request")
    
    if 'file' not in request.files or 'frame' not in request.form:
        print("✗ API: Missing file or frame data")
        return jsonify({'success': False, 'error': 'Missing file or frame data'})
    
    file = request.files['file']
    frame_filename = request.form['frame']
    size_key = request.form.get('size', 'medium')
    
    print(f"📥 API: Frame filename: {frame_filename}")
    print(f"📥 API: Size: {size_key}")
    print(f"📥 API: File: {file.filename}")
    
    if file.filename == '' or not allowed_file(file.filename):
        print("✗ API: Invalid file")
        return jsonify({'success': False, 'error': 'Invalid file'})
    
    # Save uploaded file
    filename = secure_filename(file.filename)
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)
    print(f"✓ API: File saved to: {file_path}")
    
    # Load selected frame
    frame_path = os.path.join(app.config['FRAMES_FOLDER'], frame_filename)
    print(f"📥 API: Loading frame from: {frame_path}")
    
    if not os.path.exists(frame_path):
        print(f"✗ API: Frame file not found: {frame_path}")
        return jsonify({'success': False, 'error': f'Frame file not found: {frame_filename}'})
    
    try:
        selected_glasses = load_glasses(frame_path)
        print(f"✓ API: Frame loaded successfully: {frame_filename}")
    except Exception as e:
        print(f"✗ API: Error loading frame: {str(e)}")
        return jsonify({'success': False, 'error': f'Error loading frame: {str(e)}'})
    
    # Process image
    img = cv2.imread(file_path)
    if img is None:
        return jsonify({'success': False, 'error': 'Could not process image'})
    
    # Face detection
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
        
        # Overlay glasses
        scale_factor = FRAME_SIZES.get(size_key, FRAME_SIZES['medium'])['scale_factor']
        print(f"📥 API: Applying frame with scale factor: {scale_factor}")
        try:
            overlayed_img = overlay_glasses_with_handles(
                img.copy(), landmarks_array, selected_glasses, 
                scale_factor=scale_factor
            )
            print(f"✓ API: Frame overlay successful")
            
            # Save result with timestamp to avoid caching issues
            timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
            result_filename = f'result_{timestamp}_{frame_filename}_{filename}'
            result_path = os.path.join(app.config['UPLOAD_FOLDER'], result_filename)
            cv2.imwrite(result_path, overlayed_img)
            print(f"✓ API: Result saved to: {result_filename}")
            
            result_url = url_for('uploaded_file', filename=result_filename, _external=True)
            print(f"✓ API: Result URL: {result_url}")
            
            return jsonify({
                'success': True,
                'result_url': result_url,
                'message': 'Frame applied successfully'
            })
        except Exception as e:
            print(f"✗ API: Error applying frame: {str(e)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'error': f'Error applying frame: {str(e)}'})

@app.route('/api/process_frame', methods=['POST'])
def api_process_frame():
    """Process a single frame for real-time try-on"""
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
        
        # Load selected glasses if frame is specified
        selected_glasses = None
        if frame_filename:
            frame_path = os.path.join(app.config['FRAMES_FOLDER'], frame_filename)
            try:
                selected_glasses = load_glasses(frame_path)
                print(f"Loaded frame: {frame_filename}")
            except Exception as e:
                print(f"Error loading frame {frame_filename}: {e}")
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
            _, buffer = cv2.imencode('.jpg', output_frame, [cv2.IMWRITE_JPEG_QUALITY, 70])  # Reduced from 80 to 70
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

# -------------------- EXISTING ROUTES --------------------

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
                filename = secure_filename(file.filename)
                file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                file.save(file_path)

                # Load selected glasses
                selected_frame_path = os.path.join(app.config['FRAMES_FOLDER'], selected_frame)
                try:
                    selected_glasses = load_glasses(selected_frame_path)
                except Exception as e:
                    error = f"Error loading selected frame: {str(e)}"
                    return render_template('upload.html', face_shape=face_shape, file_url=file_url, 
                                         error=error, frames=frames, selected_frame=selected_frame,
                                         frame_sizes=FRAME_SIZES, selected_size=selected_size)

                img = cv2.imread(file_path)
                if img is None:
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
                            overlay_file = os.path.join(app.config['UPLOAD_FOLDER'], 'overlay_' + filename)
                            cv2.imwrite(overlay_file, overlayed_img)
                            file_url = url_for('uploaded_file', filename='overlay_' + filename)
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
    
    frame_path = os.path.join(app.config['FRAMES_FOLDER'], frame_filename)
    
    try:
        current_glasses = load_glasses(frame_path)
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
    """Serve original frame images from frames folder"""
    return send_from_directory(app.config['FRAMES_FOLDER'], filename)

@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

# -------------------- Real-time Video --------------------
def generate_frames():
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
    
    analyzer = FaceShapeAnalyzer(analysis_duration=3.0, stability_threshold=0.8)
    distance_history = []

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
            
            # Convert landmarks to array format for distance estimation
            landmarks_array = []
            for lm in landmarks:
                landmarks_array.append([lm.x, lm.y, lm.z])
            landmarks_array = np.array(landmarks_array)
            
            # Estimate distance from camera
            distance = estimate_distance(landmarks_array)
            distance_history.append(distance)
            if len(distance_history) > 10:
                distance_history.pop(0)
            avg_distance = np.mean(distance_history)
            
            # Get distance status
            distance_status, distance_message = get_distance_status(avg_distance)
            
            # Calculate face shape
            current_shape = "Unknown"
            if face_shape_model is not None:
                try:
                    features = calculate_face_features(landmarks)
                    label = face_shape_model.predict([features])[0]
                    current_shape = get_face_shape_label(label)
                except Exception as e:
                    print(f"Prediction error: {e}")
                    current_shape = "Unknown"

            # Display information
            if distance_status == "optimal":
                color = (0, 255, 0)  # Green
            elif distance_status == "too_close":
                color = (0, 165, 255)  # Orange
            else:  # too_far
                color = (0, 0, 255)  # Red
                
            cv2.putText(display_frame, distance_message, (20, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            
            # Face shape analysis logic
            if not analyzer.analysis_complete:
                if distance_status == "optimal" and 45 <= avg_distance <= 55:
                    # Start analysis if not already started
                    if analyzer.analysis_start_time is None:
                        analyzer.start_analysis()
                    
                    # Update analysis
                    remaining = analyzer.update_analysis(current_shape, distance_status)
                    
                    if remaining > 0:
                        progress, _ = analyzer.get_analysis_progress()
                        cv2.putText(display_frame, f"Analyzing: {current_shape}", (20, 60),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                        cv2.putText(display_frame, f"Progress: {progress:.0f}%", (20, 90),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
                        cv2.putText(display_frame, f"Time left: {remaining:.1f}s", (20, 120),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
                else:
                    cv2.putText(display_frame, "Move to 45-55cm for analysis", (20, 60),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
                    analyzer.reset()
            else:
                # Analysis complete - show final result
                final_shape = analyzer.final_shape
                cv2.putText(display_frame, f"Final Shape: {final_shape}", (20, 60),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                cv2.putText(display_frame, "Click 'Get Recommendations'", (20, 90),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

            # Always show current shape for reference
            cv2.putText(display_frame, f"Current: {current_shape}", (20, 150),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

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

        else:
            # No face detected
            cv2.putText(display_frame, "No Face Detected", (20, 50),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            analyzer.reset()

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
    print(f"Optimal distance range: {OPTIMAL_DISTANCE_MIN}-{OPTIMAL_DISTANCE_MAX} cm")
    print(f"Target analysis distance: {TARGET_DISTANCE} cm")
    app.run(debug=True, host='0.0.0.0', port=5000)  # Added host and port for mobile access
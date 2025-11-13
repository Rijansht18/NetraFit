from flask import Flask, jsonify, request
import cv2
import numpy as np
import pickle
import os
import warnings
from werkzeug.utils import secure_filename
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from flask import Flask, request


app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads/'
app.config['ALLOWED_EXTENSIONS'] = {'jpg', 'jpeg', 'png'}

# Load models once
base_options = python.BaseOptions(model_asset_path='face_landmarker_v2_with_blendshapes.task')
options = vision.FaceLandmarkerOptions(
    base_options=base_options,
    output_face_blendshapes=True,
    output_facial_transformation_matrixes=True,
    num_faces=1
)
face_landmarker = vision.FaceLandmarker.create_from_options(options)

with open('Best_RandomForest.pkl', 'rb') as f:
    face_shape_model = pickle.load(f)

# Helpers
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def distance_3d(p1, p2):
    return np.linalg.norm(np.array(p1) - np.array(p2))

def calculate_face_features(coords):
    idx = {'forehead': 10, 'chin': 152, 'left_cheek': 234,
           'right_cheek': 454, 'left_eye': 263, 'right_eye': 33, 'nose_tip': 1}
    lm = {name: coords[i] for name, i in idx.items()}
    features = [
        distance_3d(lm['forehead'], lm['chin']),
        distance_3d(lm['left_cheek'], lm['right_cheek']),
        distance_3d(lm['left_eye'], lm['right_eye']),
        distance_3d(lm['nose_tip'], lm['left_eye']),
        distance_3d(lm['nose_tip'], lm['right_eye']),
        distance_3d(lm['chin'], lm['left_cheek']),
        distance_3d(lm['chin'], lm['right_cheek']),
        distance_3d(lm['forehead'], lm['left_eye']),
        distance_3d(lm['forehead'], lm['right_eye'])
    ]
    return np.array(features)

def get_face_shape_label(label):
    shapes = ["Heart", "Oval", "Round", "Square"]
    return shapes[label]

# API route
@app.route("/api/face-shape", methods=["POST"])
def api_face_shape():
    if 'file' not in request.files:
        return jsonify({"error": "No file"}), 400
    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        return jsonify({"error": "Invalid file"}), 400

    filename = secure_filename(file.filename)
    path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(path)

    img = cv2.imread(path)
    rgb_image = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_image)
    result = face_landmarker.detect(image)

    if not result.face_landmarks:
        return jsonify({"error": "No face detected"}), 400

    coords = np.array([[lm.x, lm.y, lm.z] for lm in result.face_landmarks[0]])
    features = calculate_face_features(coords)
    label = face_shape_model.predict([features])[0]
    shape = get_face_shape_label(label)

    return jsonify({
        "face_shape": shape,
        "landmarks": coords.tolist()
    })

if __name__ == "__main__":
    os.makedirs("uploads", exist_ok=True)
    app.run(host="0.0.0.0", port=5001, debug=True)

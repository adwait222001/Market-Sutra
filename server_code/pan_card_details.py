import os
import re
import cv2
import uuid
import base64
import shutil
import sqlite3
import tempfile as temp
import easyocr
from flask import request, jsonify

reader = easyocr.Reader(['en'])
UPLOAD_FOLDER = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\uploads\uploads"

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# ----------------- Utility Functions ----------------- #

def save_temp_file(file, user_id, extension):
    """Save uploaded file as a temporary file and return path + generated filename."""
    filename = f"{user_id}_{uuid.uuid4().hex}{extension}"
    temp_path = os.path.join(temp.gettempdir(), filename)
    file.save(temp_path)
    return temp_path, filename

def run_easyocr(temp_path):
    """Run EasyOCR on the given file path and return results + image."""
    result = reader.readtext(temp_path)
    image = cv2.imread(temp_path)
    return result, image

def extract_pan_details(result):
    texts = [res[1] for res in result]
    extracted_pan, extracted_name, extracted_dob = None, None, None

    # Extract PAN number
    for i, text in enumerate(texts):
        clean = re.sub(r'[^a-zA-Z]', '', text).lower()
        if "permanentaccountnumbercard" in clean and i + 1 < len(texts):
            extracted_pan = texts[i + 1]

    # Extract Name
    for i, text in enumerate(texts):
        if "name" in text.lower():
            if i + 1 < len(texts):
                extracted_name = texts[i + 1]
            break

    # Extract DOB
    for i, text in enumerate(texts):
        clean = re.sub(r'[^a-zA-Z]', '', text).lower()
        if "dateofbirth" in clean and i + 1 < len(texts):
            extracted_dob = texts[i + 1]

    return extracted_pan, extracted_name, extracted_dob

def extract_signature(result, image):
    img_h, _ = image.shape[:2]
    for (bbox, text, prob) in result:
        if "signature" in text.lower():
            x_min = int(min([pt[0] for pt in bbox]))
            x_max = int(max([pt[0] for pt in bbox]))
            y_min = int(min([pt[1] for pt in bbox]))
            y_start = max(0, y_min - 80)
            extend_down = int(img_h * 0.01)
            y_end = min(img_h, y_min + extend_down)
            signature_crop = image[y_start:y_end, x_min:x_max]
            _, buffer = cv2.imencode('.jpg', signature_crop)
            return base64.b64encode(buffer).decode('utf-8')
    return None

def extract_photo(result, image):
    img_h, img_w = image.shape[:2]
    for (bbox, text, prob) in result:
        if "name" in text.lower():
            x_min = int(min([pt[0] for pt in bbox]))
            x_max = int(max([pt[0] for pt in bbox]))
            y_min = int(min([pt[1] for pt in bbox]))
            y_start = max(0, y_min - int(img_h * 0.30))
            y_end = y_min
            extend_right = int(img_w * 0.08)
            x_max_extended = min(img_w, x_max + extend_right)
            photo_crop = image[y_start:y_end, x_min:x_max_extended]
            _, buffer = cv2.imencode('.jpg', photo_crop)
            return base64.b64encode(buffer).decode('utf-8')
    return None

# ----------------- API Functions ----------------- #

def save_uploaded_file():
    """Step 1: Save file, return temp_filename."""
    if 'file' not in request.files or 'user_id' not in request.form:
        return jsonify({'message': 'Missing file or user ID'}), 400

    file = request.files['file']
    user_id = request.form['user_id']

    if file.filename == '':
        return jsonify({'message': 'No selected file'}), 400

    # Check if a file with the same user_id already exists in uploads
    existing_files = os.listdir(UPLOAD_FOLDER)
    for f in existing_files:
        if f.startswith(user_id + "_"):
            return jsonify({"message": "A file for this user already exists!"}), 400

    # Save temp file
    _, extension = os.path.splitext(file.filename)
    temp_path, filename = save_temp_file(file, user_id, extension)

    return jsonify({
        "message": "File uploaded successfully",
        "temp_filename": filename,
        "user_id": user_id
    }), 200


def process_ocr():
    """Step 2: Run OCR on temp file and return extracted data."""
    data = request.get_json()
    temp_filename = data.get("temp_filename")

    if not temp_filename:
        return jsonify({"message": "Missing temp_filename"}), 400

    temp_path = os.path.join(temp.gettempdir(), temp_filename)
    if not os.path.exists(temp_path):
        return jsonify({"message": "File not found"}), 404

    # OCR
    result, image = run_easyocr(temp_path)
    extracted_pan, extracted_name, extracted_dob = extract_pan_details(result)
    signature_b64 = extract_signature(result, image)
    photo_b64 = extract_photo(result, image)

    if not extracted_pan or not extracted_name or not extracted_dob:
        return jsonify({"message": "Please provide a clear PAN card image"}), 404

    return jsonify({
        "name": extracted_name,
        "dob": extracted_dob,
        "pan": extracted_pan,
        "signature": signature_b64,
        "photo": photo_b64,
        "temp_filename": temp_filename
    }), 200

def confirm():
    """Step 3: Move temp file to uploads folder and insert into DB."""
    data = request.get_json()
    temp_filename = data.get("temp_filename")
    pan_number = data.get("pan")
    name = data.get("name")
    dob = data.get("dob")
    user_id = data.get("user_id")

    if not temp_filename or not pan_number or not name or not dob or not user_id:
        return jsonify({"message": "Missing required data"}), 400

    temp_path = os.path.join(temp.gettempdir(), temp_filename)
    final_path = os.path.join(UPLOAD_FOLDER, temp_filename)

    try:
        shutil.copy(temp_path, final_path)
        os.remove(temp_path)
    except Exception as e:
        return jsonify({"message": f"File handling error: {e}"}), 500

    try:
        DATABASE = 'user_pan_data.db'
        with sqlite3.connect(DATABASE) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE id = ?", (user_id,))
            if cursor.fetchone():
                return jsonify({"message": "User already exists!"}), 400
            cursor.execute("INSERT INTO users (id, name, DOB, pan) VALUES (?, ?, ?, ?)",
                           (user_id, name, dob, pan_number))
            conn.commit()
        return jsonify({"message": "User added successfully!"}), 200
    except Exception as e:
        return jsonify({"message": f"Database error: {e}"}), 500

def list_users():
    """Fetch all users from the database and return as JSON."""
    users = []
    try:
        with sqlite3.connect('user_pan_data.db') as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, name, DOB, pan FROM users")
            for row in cursor.fetchall():
                users.append({
                    "id": row[0],
                    "name": row[1],
                    "dob": row[2],
                    "pan": row[3]
                })
        return jsonify(users), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def update_animal():
    data = request.get_json()
    user_id = data.get("user_id")
    animal_type = data.get("animal_type")

    if not user_id or not animal_type:
        return jsonify({"message": "Missing data"}), 400

    try:
        with sqlite3.connect('user_pan_data.db') as conn:
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET animal_type = ? WHERE id = ?", (animal_type, user_id))
            conn.commit()
        return jsonify({"message": "Animal type updated successfully!"}), 200
    except Exception as e:
        return jsonify({"message": f"Database error: {e}"}), 500


def init_ab():
    DATABASE = 'user_pan_data.db'
    with sqlite3.connect(DATABASE) as conn:
        cursor = conn.cursor()
        cursor.execute('''CREATE TABLE IF NOT EXISTS users (
                            id TEXT PRIMARY KEY,
                            name TEXT NOT NULL,
                            DOB TEXT NOT NULL,
                            pan TEXT,
                            animal_type TEXT
                          )''')
        conn.commit()

        cursor.execute("PRAGMA table_info(users)")
        columns = [col[1] for col in cursor.fetchall()]

        if "pan" not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN pan TEXT")
        if "animal_type" not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN animal_type TEXT")

        conn.commit()

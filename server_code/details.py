import os
import sqlite3
import traceback
from flask import jsonify, request, send_from_directory
from face_detector import face

UPLOAD_FOLDER = 'uploads/'
TEMP_FOLDER = 'temp_uploads/'
DATABASE = 'user_pan_data.db'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(TEMP_FOLDER, exist_ok=True)
# ------------------ IMAGE HANDLING ------------------
def handle_image(upload_folder=UPLOAD_FOLDER):
    """Handle POST (upload) and GET (list files) requests."""
    if request.method == 'POST':
        if 'file' not in request.files or 'user_id' not in request.form:
            return jsonify({'message': 'Missing file or user ID'}), 400

        file = request.files['file']
        user_id = request.form['user_id']

        if file.filename == '':
            return jsonify({'message': 'No selected file'}), 400

        _, extension = os.path.splitext(file.filename)
        filename = f"{user_id}{extension}"
        filepath = os.path.join(upload_folder, filename)
        file.save(filepath)

        if face(filepath):
            return jsonify({"message": f'File uploaded successfully as {filename}'}), 200
        else:
            os.remove(filepath)
            return jsonify({'message': 'No face detected, please try again'}), 400

    elif request.method == 'GET':
        files = os.listdir(upload_folder)
        if not files:
            return jsonify({'message': 'No files found'}), 404
        return jsonify({'uploaded_files': files}), 200


def fetch_image(user_id, upload_folder=UPLOAD_FOLDER):
    """Fetch an uploaded file by user_id."""
    try:
        filename = next((f for f in os.listdir(upload_folder) if f.startswith(user_id)), None)
        if filename:
            return send_from_directory(upload_folder, filename)
        else:
            return jsonify({'message': 'File not found'}), 404
    except Exception as e:
        return jsonify({'message': 'Error fetching file', 'error': str(e)}), 500


# ------------------ DATABASE HANDLING ------------------

def init_db():
    """Initialize the database (create users table if not exists, without deleting data)."""
    try:
        with sqlite3.connect(DATABASE) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    dob TEXT NOT NULL
                )
            ''')
            conn.commit()
            print("✅ Database initialized (existing data preserved).")
    except sqlite3.Error as e:
        print(f"❌ Database initialization error: {e}")



def add_name():
    """Add a new user to the database."""
    try:
        data = request.get_json(force=True)
        print("Received data:", data)

        user_id = data.get('user_id')
        name = data.get('name')
        dob = data.get('dob')

        if not user_id or not name or not dob:
            return jsonify({"message": "User ID, Name, and DOB are required"}), 400

        with sqlite3.connect(DATABASE) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE id = ?", (user_id,))
            if cursor.fetchone():
                return jsonify({"message": "User already exists!"}), 400

            cursor.execute("INSERT INTO users (id, name, dob) VALUES (?, ?, ?)", (user_id, name, dob))
            conn.commit()

        return jsonify({"message": "User added successfully!"}), 200

    except sqlite3.IntegrityError as e:
        print("SQLite error:", e)
        return jsonify({"message": f"Database integrity error: {e}"}), 400
    except Exception as e:
        print("Unexpected error:", e)
        return jsonify({"message": f"Server error: {e}"}), 500


def get_names():
    """Retrieve all users from the database."""
    try:
        with sqlite3.connect(DATABASE) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, name, dob FROM users")
            users = cursor.fetchall()

        users_list = [{"id": user[0], "name": user[1], "dob": user[2]} for user in users]
        return jsonify({"users": users_list}), 200

    except sqlite3.Error as e:
        return jsonify({"message": f"Database error: {e}"}), 500


def show_name():
    """Retrieve a user's name by ID."""
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing user_id parameter"}), 400

    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM users WHERE id = ?", (user_id,))
        row = cursor.fetchone()

        if row:
            return jsonify({"name": row[0]}), 200
        else:
            return jsonify({"message": "User not found"}), 404

    except Exception as e:
        print("❌ ERROR in /name route:")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

    finally:
        conn.close()


# ------------------ CONFIRM OR CANCEL IMAGE ------------------

def confirm():
    """
    Handle confirmation or cancellation of OCR/temporary files.
    If 'confirm' → move file from temp to permanent folder.
    If 'cancel' → delete temporary file (ignore if already deleted).
    """
    try:
        data = request.get_json(force=True)
        print("Received confirm data:", data)

        temp_filename = data.get("temp_filename")
        action = data.get("action")

        if not action:
            return jsonify({"message": "Missing action"}), 400

        temp_path = os.path.join(TEMP_FOLDER, temp_filename) if temp_filename else None
        final_path = os.path.join(UPLOAD_FOLDER, temp_filename) if temp_filename else None

        # ✅ Confirm → move temp → uploads
        if action == "confirm":
            if temp_path and os.path.exists(temp_path):
                os.rename(temp_path, final_path)
                return jsonify({"message": f"File confirmed and moved to uploads as {temp_filename}"}), 200
            else:
                return jsonify({"message": "Temporary file not found for confirmation"}), 404

        # ❌ Cancel → delete temp/OCR if exists, ignore if missing
        elif action == "cancel":
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"Deleted temp file: {temp_path}")
            return jsonify({"message": "OCR and temporary file cleared"}), 200

        else:
            return jsonify({"message": "Invalid action"}), 400

    except Exception as e:
        print("Error in confirm:", e)
        return jsonify({"message": f"Server error: {str(e)}"}), 500




def check_data_complete():
    """
    Check if a user's data is complete:
    - Image exists in UPLOAD_FOLDER or UPLOAD_FOLDER/uploads
    - User details exist in the database
    """
    try:
        data = request.get_json(force=True)
        uid = data.get("uid")

        if not uid:
            return jsonify({"message": "Missing UID"}), 400

        # ------------------ Debug prints ------------------
        print("\n🔍 Incoming /check request")
        print("📦 Received UID:", uid)

        # ------------------ Image Check ------------------
        found_image = False
        folders_to_check = [UPLOAD_FOLDER, os.path.join(UPLOAD_FOLDER, "uploads")]

        for folder in folders_to_check:
            if os.path.exists(folder):
                for f in os.listdir(folder):
                    if f.startswith(uid):
                        found_image = True
                        break
            if found_image:
                break

        print("📁 Checked folders:", folders_to_check)
        print("🖼️  Image found:", found_image)
        if os.path.exists(UPLOAD_FOLDER):
            print("📂 Upload folder contents:", os.listdir(UPLOAD_FOLDER))

        # ------------------ Database Check ------------------
        user_exists = False
        with sqlite3.connect(DATABASE) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE id = ?", (uid,))
            if cursor.fetchone():
                user_exists = True

            # Optional: show all users for debugging
            cursor.execute("SELECT id, name, dob FROM users")
            print("👤 All users in DB:", cursor.fetchall())

        print("👤 User exists:", user_exists)

        # ------------------ Result ------------------
        if found_image and user_exists:
            print("✅ Data complete for UID:", uid)
            return jsonify({"message": "Data is complete"}), 200
        else:
            missing_parts = []
            if not found_image:
                missing_parts.append("image")
            if not user_exists:
                missing_parts.append("user details")

            print("⚠️  Data incomplete. Missing:", missing_parts)
            return jsonify({
                "message": "Data is not complete",
                "missing": missing_parts
            }), 400

    except Exception as e:
        print("❌ Error in check_data_complete:", e)
        return jsonify({
            "message": f"Server error: {str(e)}"
        }), 500

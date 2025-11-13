from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import os
from face_detector import face   # ✅ import face() function

UPLOAD_FOLDER = 'uploads/'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
CORS(app)
def handle_files():
    if request.method == 'POST':
        if 'file' not in request.files or 'user_id' not in request.form:
            return jsonify({'message': 'Missing file or user ID'}), 400

        file = request.files['file']
        user_id = request.form['user_id']

        if file.filename == '':
            return jsonify({'message': 'No selected file'}), 400

        _, extension = os.path.splitext(file.filename)
        filename = f"{user_id}{extension}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)

        # ✅ Run face detection
        if face(filepath):
            return jsonify({"message": f'File uploaded successfully as {filename}'}), 200
        else:
            # Delete file if no face detected
            os.remove(filepath)
            return jsonify({'message': 'No face detected, please try again'}), 400

    if request.method == 'GET':
        files = os.listdir(app.config['UPLOAD_FOLDER'])
        if not files:
            return jsonify({'message': 'No files found'}), 404
        return jsonify({'uploaded_files': files}), 200

def fetch_image(user_id):
    try:
        filename = next((f for f in os.listdir(app.config['UPLOAD_FOLDER']) if f.startswith(user_id)), None)
        if filename:
            return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
        else:
            return jsonify({'message': 'File not found'}), 404
    except Exception as e:
        return jsonify({'message': 'Error fetching file', 'error': str(e)}), 500
# ✅ Attach routes
@app.route('/files', methods=['POST', 'GET'])
def files_route():
    return handle_files()
@app.route('/files/<user_id>', methods=['GET'])
def fetch_image_route(user_id):
    return fetch_image(user_id)


if __name__ == '__main__':
    app.run(debug=True)

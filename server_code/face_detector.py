import cv2
from cvzone.FaceDetectionModule import FaceDetector
def face(img_path):
    img = cv2.imread(img_path)
    if img is None:
        print("❌ Failed to load image")
        return False

    detector = FaceDetector()
    img, bboxes = detector.findFaces(img)

    if bboxes:
        print("✅ Face detected")
        return True
    else:
        print("❌ No face detected")
        return False

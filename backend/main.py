from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
import shutil
import os

app = FastAPI(title="Smart Road Damage API")

# YOLOv8 Base Model-ah load pandrom
model = YOLO('pothole_model.pt')

@app.get("/")
def home():
    return {"message": "Backend Server is Running Successfully!", "status": "Active"}

# AI ENDPOINT: Image-ah upload panni damage detect panna
@app.post("/detect-image")
async def detect_image(file: UploadFile = File(...)):
    # 1. Vantha image-ah temporary-a save panna
    file_path = f"temp_{file.filename}"
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # 2. YOLOv8 AI model-ah image mela run panna
    results = model(file_path)
    
    # 3. Output-ah JSON format-la edukka
    detections = []
    for r in results:
        for box in r.boxes:
            detections.append({
                "class_name": model.names[int(box.cls)], 
                "confidence": round(float(box.conf) * 100, 2), 
                "bounding_box": box.xyxy[0].tolist() 
            })
            
    # 4. Save panna temp file-ah delete pannida
    os.remove(file_path)
    
    return {"filename": file.filename, "detections": detections}
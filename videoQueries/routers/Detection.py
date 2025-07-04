import shutil
from fastapi import FastAPI, WebSocket, Depends, HTTPException, File, UploadFile
from fastapi import APIRouter, Query
from videoQueries.models.Detection import Detection
from ultralytics import YOLO
from videoQueries.database import get_db
import cv2
from typing import List
import time
from sqlalchemy.orm import Session
import asyncio
from videoQueries.schemas.Detection import DetectionResponse
from fastapi.responses import FileResponse
import os
import uuid



router = APIRouter()

model = YOLO("./Detection_model/best.pt")  # Предобученная или твоя модель

@router.websocket("/ws/camera/{examination_id}")
async def websocket_endpoint(websocket: WebSocket, examination_id: str, db: Session = Depends(get_db)):
    await websocket.accept()
    cap = cv2.VideoCapture(0)
    start_time = time.time()

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            results = model(frame)[0]
            current_time = time.time() - start_time

            detections = []
            for box in results.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                cls = int(box.cls[0])
                label = model.names[cls]
                conf = float(box.conf[0])

                # Сохраняем в БД
                db_detection = Detection(
                    examination_id=examination_id,
                    timestamp=current_time,
                    x1=x1, y1=y1, x2=x2, y2=y2,
                    label=label,
                    confidence=conf
                )
                db.add(db_detection)

                detections.append({
                    "x1": x1, "y1": y1, "x2": x2, "y2": y2,
                    "label": label, "confidence": conf,
                    "timestamp": current_time
                })

            db.commit()
            await websocket.send_json({"detections": detections})
            await asyncio.sleep(0.03)

    except Exception as e:
        print(f"WebSocket connection closed: {e}")
    finally:
        cap.release()


@router.post("/process_video/{examination_id}")
async def process_video(
        examination_id: str,
        video_file: UploadFile = File(...),
        db: Session = Depends(get_db)
):
    # Подготовка путей
    storage_dir = f"examinations_storage/{examination_id}"
    os.makedirs(storage_dir, exist_ok=True)

    input_path = os.path.join(storage_dir, f"input_{uuid.uuid4().hex}.mp4")
    output_path = os.path.join(storage_dir, f"annotated_{uuid.uuid4().hex}.mp4")

    # Сохраняем входное видео
    with open(input_path, "wb") as f:
        shutil.copyfileobj(video_file.file, f)

    # Открываем видео
    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video file at {input_path}")

    # Видео параметры
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 25
    writer = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (width, height))

    all_detections = []
    start_time = time.time()

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Инференс
        results = model(frame)[0]
        current_time = time.time() - start_time

        for box in results.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cls = int(box.cls[0])
            label = model.names[cls]
            conf = float(box.conf[0])

            # Сохраняем в БД
            db_detection = Detection(
                examination_id=examination_id,
                timestamp=current_time,
                x1=x1, y1=y1, x2=x2, y2=y2,
                label=label,
                confidence=conf
            )
            db.add(db_detection)

            # Рисуем на кадре
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, f"{label} {conf:.2f}", (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

    # Завершение
    db.commit()
    cap.release()
    writer.release()

    return FileResponse(path=output_path, media_type="video/mp4", filename="annotated.mp4")



@router.get("/examinations/{examination_id}/detections", response_model=List[DetectionResponse])
def get_detections_for_examination(
    examination_id: str,
    db: Session = Depends(get_db)
):
    detections = db.query(Detection) \
        .filter(Detection.examination_id == examination_id) \
        .order_by(Detection.timestamp.asc()) \
        .all()

    if not detections:
        raise HTTPException(status_code=404, detail="Detections not found for this examination")
    return detections

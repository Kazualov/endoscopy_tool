from fastapi import FastAPI, WebSocket, Depends, HTTPException
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

router = APIRouter()

model = YOLO("videoQueries/Detection_model/best.pt")  # Предобученная или твоя модель

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

@router.websocket("/ws/video/{examination_id}")
async def websocket_endpoint(
    websocket: WebSocket, examination_id: str,
    video_path: str = Query(...),
    db: Session = Depends(get_db)
):
    await websocket.accept()

    cap = cv2.VideoCapture(video_path)
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

        # После окончания видео — можно послать клиенту сообщение или просто закрыть ws
        await websocket.close()

    except Exception as e:
        print(f"WebSocket connection closed: {e}")

    finally:
        cap.release()

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

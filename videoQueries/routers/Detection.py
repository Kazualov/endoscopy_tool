from fastapi import FastAPI, WebSocket, Depends, HTTPException
from pathlib import Path
from fastapi import APIRouter, Query
from videoQueries.models.Detection import Detection
from videoQueries.models.Examination import Examination
from ultralytics import YOLO
from videoQueries.database import get_db
import cv2
from typing import List
import time
from sqlalchemy.orm import Session
import asyncio
from videoQueries.schemas.Detection import DetectionResponse
import sys
import os

def get_model_path() -> str:
    if getattr(sys, 'frozen', False):
        # При запуске из .exe (PyInstaller)
        base = sys._MEIPASS

        # Проверим оба возможных варианта пути
        path1 = os.path.join(base, "videoQueries", "Detection_model", "best.pt")
        path2 = os.path.join(base, "Detection_model", "best.pt")

        if os.path.exists(path1):
            return path1
        elif os.path.exists(path2):
            return path2
        else:
            raise FileNotFoundError("Model file not found in .exe bundle.")
    else:
        # Обычный запуск из исходников
        base = os.path.dirname(__file__)
        path = os.path.join(base, "videoQueries", "Detection_model", "best.pt")
        if not os.path.exists(path):
            raise FileNotFoundError(f"Model not found at {path}")
        return path


model_path = get_model_path()
model = YOLO(model_path)


router = APIRouter()


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

@router.post("/examinations/{examination_id}/process_video/", response_model=dict)
async def process_video(
    examination_id: str,
    video_path: str = Query(...),
    db: Session = Depends(get_db)
):
    # Проверка существования осмотра
    exam = db.query(Examination).filter(Examination.id == examination_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    # Открытие видео
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise HTTPException(status_code=400, detail="Не получается открыть видео")

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Подготовка выходного видео
    input_stem = Path(video_path).stem  # Без расширения
    output_filename = f"{input_stem}_detection.mp4"
    output_path = Path(exam.folder_path) / output_filename

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(str(output_path), fourcc, fps, (width, height))

    start_time = time.time()
    all_detections = []

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        results = model(frame)[0]
        current_time = time.time() - start_time

        for box in results.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cls = int(box.cls[0])
            label = model.names[cls]
            conf = float(box.conf[0])

            # Рисуем прямоугольник и подпись
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(
                frame, f"{label} {conf:.2f}",
                (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                (0, 255, 0), 2
            )

            # Сохраняем в БД
            db_detection = Detection(
                examination_id=examination_id,
                timestamp=current_time,
                x1=x1, y1=y1, x2=x2, y2=y2,
                label=label,
                confidence=conf
            )
            db.add(db_detection)

            all_detections.append({
               "examination_id": examination_id,
                "x1": x1, "y1": y1, "x2": x2, "y2": y2,
                "label": label, "confidence": conf,
                "timestamp": current_time
            })

        # Сохраняем кадр с аннотациями в видео
        out.write(frame)

    # Завершаем работу
    cap.release()
    out.release()
    db.commit()
    response_detections = [
        DetectionResponse(**d) for d in all_detections
    ]
    return {
        "annotated_video_filename": output_filename,
        "annotated_video_path": str(output_path),
        "detections": all_detections
    }


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

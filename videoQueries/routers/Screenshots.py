from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.responses import FileResponse
from videoQueries.models.Examination import Examination
from videoQueries.models.Screenshot import Screenshot
from videoQueries.models.video import Video
from videoQueries.database import SessionLocal
import shutil, uuid, os
from typing import List
from videoQueries.schemas.screenshots import ScreenshotResponse
from pathlib import Path

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

router = APIRouter()

SCREENSHOT_DIR = Path(__file__).resolve().parent.parent / "data" / "screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

@router.post("/exams/{exam_id}/upload_screenshot/")
async def upload_screenshot(
    exam_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    screenshot = Screenshot(
        exam_id=exam_id,
        filename=file.filename,
        file_path=""
    )
    db.add(screenshot)
    db.flush()

    filename = f"{exam_id}_screenshot_{screenshot.id:05d}.png"
    filepath = SCREENSHOT_DIR / filename

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    screenshot.file_path = str(filepath)
    screenshot.filename = filename
    db.commit()

    return {"screenshot_id": screenshot.id, "filename": filename}


@router.get("/exams/{exam_id}/screenshots", response_model=List[ScreenshotResponse])
def get_screenshots(exam_id: str, db: Session = Depends(get_db)):
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    screenshots = (
        db.query(Screenshot)
        .filter(Screenshot.exam_id == exam_id)
        .order_by(Screenshot.created_at)
        .all()
    )

    result = []
    for shot in screenshots:
        if os.path.exists(shot.file_path):
            result.append({
                "screenshot_id": shot.id,
                "exam_id": shot.exam_id,
                "filename": shot.filename,
                "file_path": shot.file_path,
                "created_at": shot.created_at
            })

    return result


@router.get("/screenshots/{screenshot_id}/file", response_class=FileResponse)
def get_screenshot_file(screenshot_id: int, db: Session = Depends(get_db)):
    screenshot = db.query(Screenshot).filter(Screenshot.id == screenshot_id).first()
    if not screenshot or not os.path.exists(screenshot.file_path):
        raise HTTPException(status_code=404, detail="Скриншот не найден")

    return FileResponse(screenshot.file_path, media_type="image/jpeg")  # или image/jpeg






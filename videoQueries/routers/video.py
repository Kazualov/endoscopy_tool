from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.responses import FileResponse
from videoQueries.models.Examination import Examination
from videoQueries.models.video import Video
from videoQueries.database import SessionLocal
import shutil, uuid, os
from pathlib import Path
from videoQueries.database import get_db
router = APIRouter()


VIDEO_DIR = Path(__file__).resolve().parent.parent / "data" / "videos"


@router.post("/upload/")
async def upload_video(
        file: UploadFile = File(...),
        patient_id: str = Form(...),
        description: str = Form(""),
        notes: str = Form(""),
        timestamp: str = Form(""),
        db: Session = Depends(get_db)
):
    video_id = str(uuid.uuid4())
    file_path = os.path.join(VIDEO_DIR, f"{video_id}_{file.filename}")

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    video = Video(
        id=video_id,
        filename=file.filename,
        patient_id=patient_id,
        description=description,
        notes=notes,
        timestamp=timestamp,
        file_path=file_path
    )

    db.add(video)
    db.commit()

    return {"video_id": video_id, "message": "Video uploaded successfully"}


@router.get("/videos/")
def list_videos(db: Session = Depends(get_db)):
    videos = db.query(Video).all()
    return [
        {
            "video_id": video.id,
            "filename": video.filename,
            "patient_id": video.patient_id,
            "description": video.description,
            "notes": video.notes,
            "timestamp": video.timestamp
        }
        for video in videos
    ]


@router.get("/videos/{video_id}")
def get_video(video_id: str, db: Session = Depends(get_db)):
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    return {
        "video_id": video.id,
        "filename": video.filename,
        "patient_id": video.patient_id,
        "description": video.description,
        "notes": video.notes,
        "timestamp": video.timestamp,
        "file_path": video.file_path
    }


#Получение видео по ID
@router.get("/videos/{video_id}/file", response_class=FileResponse)
def serve_video(video_id: str):
    db = SessionLocal()
    video = db.query(Video).filter(Video.id == video_id).first()
    db.close()

    if not video or not os.path.exists(video.file_path):
        raise HTTPException(status_code=404, detail="Видео не найдено")

    return FileResponse(path=video.file_path, media_type="video/mp4")


@router.delete("/videos/{video_id}")
def delete_video(video_id: str, db: Session = Depends(get_db)):
    video = db.query(Video).filter(Video.id == video_id).first()

    if not video:
        raise HTTPException(status_code=404, detail="Видео не найдено")

    if os.path.exists(video.file_path):
        os.remove(video.file_path)

    db.delete(video)
    db.commit()
    return {"message": "Видео удалено"}

from fastapi.responses import FileResponse

@router.get("/examinations/{exam_id}/video")
def get_video_by_examination(exam_id: str, db: Session = Depends(get_db)):
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    if not exam.video:
        raise HTTPException(status_code=404, detail="Видео для осмотра не найдено")

    if not os.path.exists(exam.video.file_path):
        raise HTTPException(status_code=404, detail="Файл видео не существует на диске")

    return FileResponse(path=exam.video.file_path, media_type="video/mp4", filename=exam.video.filename)


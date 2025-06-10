from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from videoQueries.models.video import Video
from videoQueries.database import SessionLocal
import shutil, uuid, os

router = APIRouter()
VIDEO_DIR = "videoQueries/data/videos"


# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/upload/")
async def upload_video(
        file: UploadFile = File(...),
        patient_id: str = Form(...),
        description: str = Form(""),
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
        "timestamp": video.timestamp,
        "file_path": video.file_path
    }
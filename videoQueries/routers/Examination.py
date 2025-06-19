from videoQueries.schemas.examination import ExaminationCreate, ExaminationResponse
from typing import List
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from videoQueries.models.patient import Patient
from sqlalchemy.orm import Session
import shutil
import uuid
from videoQueries.models.video import Video
from videoQueries.models.Examination import Examination
from videoQueries.database import get_db
from pathlib import Path

router = APIRouter()



@router.post("/examinations/", response_model=ExaminationResponse)
def create_examination(
    data: ExaminationCreate,
    db: Session = Depends(get_db)
):
    patient = db.query(Patient).filter(Patient.id == data.patient_id).first()
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Пациент с id={data.patient_id} не найден"
        )
    exam = Examination(
        id=str(uuid.uuid4()),
        patient_id=data.patient_id,
        description=data.description
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return exam



@router.get("/examinations/", response_model=List[ExaminationResponse])
def get_examinations(db: Session = Depends(get_db)):
    return db.query(Examination).order_by(Examination.date.desc()).all()


@router.get("/examinations/{exam_id}", response_model=ExaminationResponse)
def get_examination(exam_id, db: Session = Depends(get_db)):
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")
    return exam

@router.post("/examinations/{examination_id}/video/")
async def upload_video_to_examination(
    examination_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    exam = db.query(Examination).filter(Examination.id == examination_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    if exam.video_id:
        raise HTTPException(status_code=400, detail="У этого осмотра уже есть видео")

    video_id = str(uuid.uuid4())
    save_path = Path(__file__).resolve().parent.parent / "data" / "videos" / f"{video_id}_{file.filename}"
    #save_path = f"./data/videos/{video_id}_{file.filename}"

    with open(save_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    video = Video(
        id=video_id,
        filename=file.filename,
        file_path=str(save_path),
    )
    db.add(video)
    db.commit()

    # привязываем к осмотру
    exam.video_id = video_id
    db.commit()
    db.refresh(exam)

    return {"video_id": video_id, "message": "Видео добавлено к осмотру"}


@router.delete("/examinations/{examination_id}")
def delete_examination(examination_id: str, db: Session = Depends(get_db)):
    examination = db.query(Examination).filter(Examination.id == examination_id).first()

    if not examination:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    db.delete(examination)
    db.commit()
    return {"message": "Осмотр удалён"}

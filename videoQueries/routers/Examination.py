from videoQueries.schemas.examination import ExaminationCreate, ExaminationResponse
from typing import List
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Form, Request
from videoQueries.models.patient import Patient
from sqlalchemy.orm import Session
import shutil
import uuid
import json
from videoQueries.models.video import Video
from videoQueries.models.Examination import Examination
from videoQueries.database import get_db
from pathlib import Path

router = APIRouter()


DEFAULT_STORAGE_PATH = Path("./examinations_storage")  # путь по умолчанию


@router.post("/examinations/", response_model=ExaminationResponse)
def create_examination(
        data: ExaminationCreate,
        request: Request,
        db: Session = Depends(get_db)
):
    # 1. Проверка пациента
    patient = db.query(Patient).filter(Patient.id == data.patient_id).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Пациент не найден")

    # 2. Создание уникального ID
    exam_id = str(uuid.uuid4())

    # 3. Получение базового пути
    base_path = getattr(request.app.state, "base_storage_path", None)
    print(base_path)
    if not base_path:
        base_path = DEFAULT_STORAGE_PATH

    base_path = Path(base_path)
    exam_folder = base_path / exam_id
    screenshots_path = exam_folder / "screenshots"

    folder_path = str(exam_folder)  # сохраняется в БД

    try:
        # 4. Создание директорий
        exam_folder.mkdir(parents=True, exist_ok=True)
        screenshots_path.mkdir(parents=True, exist_ok=True)

        # 5. Сохраняем patient.json
        with open(exam_folder / "patient.json", "w", encoding="utf-8") as f:
            json.dump({"id": patient.id, "name": patient.name}, f, ensure_ascii=False, indent=2)

        # 6. Сохраняем описание, если есть
        if data.description:
            with open(exam_folder / "description.txt", "w", encoding="utf-8") as f:
                f.write(data.description)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при создании файлов: {e}")

    # 7. Создание объекта осмотра
    exam = Examination(
        id=exam_id,
        patient_id=data.patient_id,
        description=data.description,
        folder_path=folder_path
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
        notes: str = Form(""),
        db: Session = Depends(get_db)
):
    exam = db.query(Examination).filter(Examination.id == examination_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")
    existing_video = db.query(Video).filter(Video.examination_id == examination_id).first()
    if existing_video:
            raise HTTPException(
                status_code=400,
                detail="Video already exists for this examination"
            )
    base_path = Path(exam.folder_path)
    base_path.mkdir(parents=True, exist_ok=True)  # вдруг удалили

    video_id = str(uuid.uuid4())
    file_ext = Path(file.filename).suffix
    video_filename = f"video{file_ext}"
    save_path = base_path / video_filename

    with open(save_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    notes_path = base_path / "notes.json"
    with open(notes_path, "w", encoding="utf-8") as f:
        json.dump({"notes": notes}, f, ensure_ascii=False, indent=2)
# comment
    video = Video(id=video_id, filename=file.filename, file_path=str(save_path))
    db.add(video)

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

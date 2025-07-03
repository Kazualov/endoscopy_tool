import os
import shutil
from pathlib import Path
from typing import List
import io
import zipfile
from fastapi.responses import StreamingResponse
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
import json
from videoQueries.database import SessionLocal
from videoQueries.models.Examination import Examination
from videoQueries.models.Screenshot import Screenshot
from videoQueries.schemas.screenshots import ScreenshotResponse


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
    # Получаем осмотр из БД
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    # Создаем запись для скриншота в БД (без пути пока)
    screenshot = Screenshot(
        exam_id=exam_id,
        filename=file.filename,
        file_path=""
    )
    db.add(screenshot)
    db.flush()  # Получаем ID скриншота до коммита

    # Используем путь из БД
    try:
        screenshots_dir = Path(exam.folder_path) / "screenshots"
        screenshots_dir.mkdir(parents=True, exist_ok=True)

        # Уникальное имя скриншота
        filename = f"{exam_id}_screenshot_{screenshot.id:05d}.jpg"
        filepath = screenshots_dir / filename

        # Сохраняем файл
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Обновляем путь в объекте Screenshot
        screenshot.file_path = str(filepath)
        screenshot.filename = filename
        db.commit()

        return {
            "screenshot_id": screenshot.id,
            "filename": filename
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при сохранении скриншота: {e}")



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
                "created_at": shot.created_at,
                "annotated_filename": shot.annotated_filename,
                "annotated_file_path": shot.annotated_file_path,
            })

    return result



@router.get("/screenshots/{screenshot_id}/file")
def get_screenshot_file(screenshot_id: int, db: Session = Depends(get_db)):
    screenshot = db.query(Screenshot).filter(Screenshot.id == screenshot_id).first()
    if not screenshot or not os.path.exists(screenshot.file_path):
        raise HTTPException(status_code=404, detail="Скриншот не найден")

    # Создаем ZIP в памяти
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w") as zip_file:
        zip_file.write(screenshot.file_path, arcname="original.jpg")

        # Проверяем наличие аннотированного изображения
        if screenshot.annotated_file_path and os.path.exists(screenshot.annotated_file_path):
            zip_file.write(screenshot.annotated_file_path, arcname="annotated.jpg")

    zip_buffer.seek(0)
    return StreamingResponse(zip_buffer, media_type="application/zip", headers={
        "Content-Disposition": f"attachment; filename=screenshot_{screenshot_id}.zip"
    })


@router.post("/screenshots/{screenshot_id}/upload_annotated/")
async def upload_annotated_screenshot(
    screenshot_id: int,
    annotated_file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    screenshot = db.query(Screenshot).filter(Screenshot.id == screenshot_id).first()
    if not screenshot:
        raise HTTPException(status_code=404, detail="Скриншот не найден")

    # Проверяем, связан ли скриншот с осмотром
    exam = db.query(Examination).filter(Examination.id == screenshot.exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    try:
        screenshots_dir = Path(exam.folder_path) / "annotated_screenshots"
        screenshots_dir.mkdir(parents=True, exist_ok=True)

        annotated_filename = f"{screenshot.exam_id}_screenshot_{screenshot.id:05d}_annotated.jpg"
        annotated_filepath = screenshots_dir / annotated_filename

        # Сохраняем аннотированный файл
        with open(annotated_filepath, "wb") as buffer:
            shutil.copyfileobj(annotated_file.file, buffer)

        screenshot.annotated_file_path = str(annotated_filepath)
        screenshot.annotated_filename = annotated_filename

        db.commit()

        return {
            "annotated_filename": annotated_filename,
            "file_path": str(annotated_filepath)
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при сохранении аннотированного скриншота: {e}")

@router.put("/exams/{exam_id}/annotated_screenshots/{source_screenshot_id}")
async def update_annotated_screenshot(
    exam_id: str,
    source_screenshot_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # Проверка осмотра
    exam = db.query(Examination).filter(Examination.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Осмотр не найден")

    # Проверка существования исходного скриншота
    source = db.query(Screenshot).filter(Screenshot.id == source_screenshot_id).first()
    if not source or source.exam_id != exam_id:
        raise HTTPException(status_code=404, detail="Исходный скриншот не найден")

    try:
        annotated_dir = Path(exam.folder_path) / "screenshots" / "annotated"
        annotated_dir.mkdir(parents=True, exist_ok=True)

        filename = f"{exam_id}_screenshot_{source.id:05d}_annotated.jpg"
        filepath = annotated_dir / filename

        if not filepath.exists():
            raise HTTPException(status_code=404, detail="Аннотированный скриншот не найден для обновления")

        # Перезаписываем файл
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        return {
            "filename": filename,
            "file_path": str(filepath)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при обновлении: {e}")


@router.delete("/screenshots/{screenshot_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_screenshot(screenshot_id: int, db: Session = Depends(get_db)):
    screenshot = db.query(Screenshot).filter(Screenshot.id == screenshot_id).first()
    if not screenshot:
        raise HTTPException(status_code=404, detail="Скриншот не найден")

    # Удаляем файлы, если они существуют
    try:
        if screenshot.file_path and os.path.exists(screenshot.file_path):
            os.remove(screenshot.file_path)
        if screenshot.annotated_file_path and os.path.exists(screenshot.annotated_file_path):
            os.remove(screenshot.annotated_file_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении файлов: {str(e)}")

    # Удаляем запись из базы
    db.delete(screenshot)
    db.commit()

    # Возвращаем 204 No Content (успешно, тело ответа пустое)


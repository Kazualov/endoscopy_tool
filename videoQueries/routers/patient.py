from fastapi import APIRouter, HTTPException, Depends, Form, Body, Query
from sqlalchemy.orm import Session
import uuid
from fastapi.responses import JSONResponse
from videoQueries.models.patient import Patient
from videoQueries.models.video import Video
from videoQueries.schemas.patient import PatientCreate, PatientOut
from videoQueries.database import get_db
from videoQueries.database import Base, engine



router = APIRouter()


@router.get("/patients/", response_model=list[PatientOut])
def get_patients(db: Session = Depends(get_db)):
    return db.query(Patient).all()

@router.get("/patients/search")
def search_patients(name: str = Query(...), db: Session = Depends(get_db)):

    results = db.query(Patient).filter(Patient.name.ilike(f"%{name}%")).all()
    db.close()

    if not results:
        return JSONResponse(content=[], status_code=200)

    return [
        {
            "id": p.id,
            "name": p.name,
            "surname": p.surname,
            "middlename": p.middlename,
            "birthday": p.birthday,
            "gender": p.gender,
        }
        for p in results
    ]

@router.get("/patients/{patient_id}", response_model=PatientOut)
def get_patient(patient_id: str, db: Session = Depends(get_db)):
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise HTTPException(status_code=404, detail= "Patient not found")
    return {
        "id": patient.id,
        "name": patient.name,
        "surname": patient.surname,
        "middlename": patient.middlename,
        "birthday": patient.birthday,
        "gender": patient.gender,
    }


@router.post("/patients/", status_code=201)
def create_patient(
    patient: PatientCreate = Body(...),
    db: Session = Depends(get_db)
):
    new_patient = Patient(
        id= str(uuid.uuid4()),
        name= patient.name,
        surname= patient.surname,
        middlename= patient.middlename,
        birthday= patient.birthday,
        gender= patient.gender

    )
    db.add(new_patient)
    db.commit()
    db.refresh(new_patient)
    return new_patient

@router.put("/patient/{patient_id}", response_model=PatientOut)
def update_patient(patient_id: str, updated_data: PatientCreate, db: Session = Depends(get_db)):
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    for key, value in updated_data.model_dump().items():
        setattr(patient, key, value)
    db.commit()
    db.refresh(patient)
    return patient


#Для получения всех видео по ID пациента
@router.get("/patients/{patient_id}/videos")
def get_patient_videos(patient_id: str, db: Session = Depends(get_db)):
    patient_exists = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient_exists:
        db.close()
        raise HTTPException(status_code=404, detail="Пациент не найден")
    videos = db.query(Video).filter(Video.patient_id == patient_id).all()
    db.close()

    if not videos:
        return []

    return [v for v in videos]

@router.delete("/patient/{patient_id}")
def delete_patient(patient_id: str, db: Session = Depends(get_db)):
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        db.close()
        raise HTTPException(status_code=404, detail="Пациент не найден")

    db.delete(patient)
    db.commit()
    return {"message": "Пациент удалён"}
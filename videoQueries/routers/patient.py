from fastapi import APIRouter, HTTPException, Depends, Form, Body
from sqlalchemy.orm import Session
import uuid
from videoQueries.models.patient import Patient
from videoQueries.schemas.patient import PatientCreate, PatientOut
from videoQueries.database import get_db
from videoQueries.database import Base, engine


router = APIRouter()


@router.get("/patients/", response_model=list[PatientOut])
def get_patients(db: Session = Depends(get_db)):
    return db.query(Patient).all()


@router.get("/patients/{patient_id}", response_model=PatientOut)
def get_patient(patient_id: str, db: Session = Depends(get_db)):
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise HTTPException(status_code=404, detail= "Patient not found")
    return patient


@router.post("/patients/", response_model=PatientOut)
def create_patient(
    patient: PatientCreate = Body(...),
    db: Session = Depends(get_db)
):
    patient_id = str(uuid.uuid4())
    new_patient = Patient(
        id=patient_id,
        name=patient.name,
        age=patient.age,
        gender=patient.gender
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


@router.delete("/patients/")
def delete_patients(db: Session = Depends(get_db)):
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

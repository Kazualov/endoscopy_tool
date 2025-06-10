from fastapi import APIRouter, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from videoQueries.models.recording import RecordingSession
from videoQueries.database import SessionLocal
import uuid, datetime

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/record/start")
def start_recording(patient_id: str = Form(...), db: Session = Depends(get_db)):
    # Check if there’s an ongoing session for this patient
    ongoing = db.query(RecordingSession).filter(
        RecordingSession.patient_id == patient_id,
        RecordingSession.stopped_at == None
    ).first()

    if ongoing:
        raise HTTPException(status_code=400, detail="Recording already in progress")

    session_id = str(uuid.uuid4())
    session = RecordingSession(id=session_id, patient_id=patient_id)
    db.add(session)
    db.commit()

    return {"session_id": session_id, "message": "Recording started"}

@router.post("/record/stop")
def stop_recording(patient_id: str = Form(...), db: Session = Depends(get_db)):
    session = db.query(RecordingSession).filter(
        RecordingSession.patient_id == patient_id,
        RecordingSession.stopped_at == None
    ).first()

    if not session:
        raise HTTPException(status_code=400, detail="No active recording found")

    session.stopped_at = datetime.datetime.utcnow()
    db.commit()

    return
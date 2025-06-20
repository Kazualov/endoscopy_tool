from sqlalchemy import Column, String, DateTime
from videoQueries.database import Base
import datetime

class RecordingSession(Base):
    __tablename__ = "recording_sessions"
    
    id = Column(String, primary_key=True, index=True)
    patient_id = Column(String, nullable=False)
    started_at = Column(DateTime, default=datetime.datetime.utcnow)
    stopped_at = Column(DateTime, nullable=True)

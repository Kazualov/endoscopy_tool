# models/examination.py

from sqlalchemy import Column, String, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from videoQueries.database import Base  # Импорт единого Base


class Examination(Base):
    __tablename__ = "examinations"
    id = Column(String, primary_key=True, index=True)
    patient_id = Column(String, ForeignKey("patients.id"))
    description = Column(String)
    date = Column(DateTime, default=func.now())
    folder_path = Column(String, nullable=False)
    video_id = Column(String, ForeignKey("videos.id"), nullable=True, unique=True)

    # связь с пациентом
    patient = relationship("Patient", back_populates="examinations")
    # связь с видео
    video = relationship("Video", back_populates="examination", uselist=False)
    #связь с детекцией
    #detections = relationship("Detection", back_populates="examination", cascade="all, delete")

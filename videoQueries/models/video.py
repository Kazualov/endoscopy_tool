from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.orm import relationship
from videoQueries.database import Base

class Video(Base):
    __tablename__ = "videos"

    id = Column(String, primary_key=True, index=True)
    filename = Column(String)
    patient_id = Column(String)
    description = Column(String)
    notes = Column(String)
    timestamp = Column(String)
    file_path = Column(String)
    examination_id = Column(String, ForeignKey('examinations.id'))

    # Simplified relationship
    examination = relationship("Examination", back_populates="video")
from sqlalchemy import Column, String, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship, deferred
from videoQueries.database import Base

class Examination(Base):
    __tablename__ = "examinations"

    id = Column(String, primary_key=True, index=True)
    patient_id = Column(String, ForeignKey("patients.id"))
    description = Column(String)
    date = Column(DateTime, default=func.now())
    folder_path = Column(String, nullable=False)

    # Relationships
    patient = relationship("Patient", back_populates="examinations")
    video = relationship(
        "Video",
        back_populates="examination",
        uselist=False,
        cascade="all, delete-orphan"
    )
    detections = relationship("Detection", back_populates="examination", cascade="all, delete")

    # Add hybrid property for video_id
    @property
    def video_id(self):
        return self.video.id if self.video else None
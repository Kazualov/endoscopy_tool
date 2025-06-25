from sqlalchemy import Column, Integer, String, ForeignKey, Float
from sqlalchemy.orm import relationship
from videoQueries.database import Base # или где у вас объявлен Base
class Detection(Base):
    __tablename__ = "detections"
    id = Column(Integer, primary_key=True, index=True)
    examination_id = Column(String, ForeignKey("examinations.id"))
    timestamp = Column(Float, nullable=False)
    x1 = Column(Integer)
    y1 = Column(Integer)
    x2 = Column(Integer)
    y2 = Column(Integer)
    label = Column(String)
    confidence = Column(Float)

    examination = relationship("Examination", back_populates="detections")

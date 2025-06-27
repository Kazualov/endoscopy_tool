from sqlalchemy import Column, String, Integer, ForeignKey, Float, DateTime, Boolean
from videoQueries.database import Base


class Screenshot(Base):
    __tablename__ = "screenshots"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    exam_id = Column(String, ForeignKey("examinations.id"), nullable=False)  # изменено
    filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    timestamp_in_video = Column(String, nullable=False)

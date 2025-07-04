from sqlalchemy import Column, String, Integer, ForeignKey, DateTime
from videoQueries.database import Base
from datetime import datetime

class Screenshot(Base):
    __tablename__ = "screenshots"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    exam_id = Column(String, ForeignKey("examinations.id"), nullable=False)
    filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    timestamp_in_video = Column(String, nullable=False)
    timestamp_in_seconds = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    annotated_filename = Column(String, nullable=True)
    annotated_file_path = Column(String, nullable=True)

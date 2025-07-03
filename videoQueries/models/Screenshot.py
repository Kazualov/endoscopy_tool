from sqlalchemy import Column, String, Integer, ForeignKey
from videoQueries.database import Base

class Screenshot(Base):
    __tablename__ = "screenshots"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    exam_id = Column(String, ForeignKey("examinations.id"), nullable=False)
    filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    timestamp_in_video = Column(String, nullable=False)

    annotated_filename = Column(String, nullable=True)
    annotated_file_path = Column(String, nullable=True)

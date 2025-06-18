from sqlalchemy import Column, String
from sqlalchemy.ext.declarative import declarative_base


Base = declarative_base()


class Video(Base):
    __tablename__ = "videos"

    id = Column(String, primary_key=True, index=True)
    filename = Column(String)
    patient_id = Column(String)
    description = Column(String)
    notes = Column(String)
    timestamp = Column(String)
    file_path = Column(String)

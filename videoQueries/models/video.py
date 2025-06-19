from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.orm import relationship
from videoQueries.database import Base
from videoQueries.models.Examination import Examination

# models/Video.py
class Video(Base):
    __tablename__ = "videos"

    id = Column(String, primary_key=True, index=True)
    filename = Column(String)
    patient_id = Column(String)
    description = Column(String)
    notes = Column(String)
    timestamp = Column(String)
    file_path = Column(String)

    # Вторая сторона one-to-one
    examination = relationship(
        "Examination",
        back_populates="video",
        uselist=False,
        primaryjoin="Video.id==foreign(Examination.video_id)",  # добавлено foreign()
        foreign_keys=[Examination.video_id]  # передаём объект колонки, а не строку
    )


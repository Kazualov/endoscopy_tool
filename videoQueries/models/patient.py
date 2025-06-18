from sqlalchemy import Column, String
from videoQueries.database import Base
from sqlalchemy.orm import relationship


class Patient(Base):
    __tablename__ = "patients"

    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    age = Column(String)
    gender = Column(String)
    examinations = relationship("Examination", back_populates="patient")


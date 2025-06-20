from sqlalchemy import Column, String, Date
from videoQueries.database import Base
from sqlalchemy.orm import relationship


class Patient(Base):
    __tablename__ = "patients"
    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    surname = Column(String, nullable=False)
    middlename = Column(String, nullable=False)
    birthday = Column(Date, nullable=False)
    gender = Column(String, nullable=False)
    examinations = relationship("Examination", back_populates="patient")



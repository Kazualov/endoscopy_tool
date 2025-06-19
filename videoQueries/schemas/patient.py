from pydantic import BaseModel
from typing import Optional
from datetime import date


class PatientBase(BaseModel):
    name: str
    surname: str
    middlename: Optional[str] = None
    birthday: Optional[date] = None
    gender: Optional[str] = None

class PatientCreate(PatientBase):
    pass

class PatientOut(PatientBase):
    id: str

    class Config:
        from_attributes = True

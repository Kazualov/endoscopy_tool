from pydantic import BaseModel
from typing import Optional
from datetime import date


class PatientBase(BaseModel):
    id: str


class PatientCreate(PatientBase):
    pass


class PatientOut(PatientBase):
    name: str

    class Config:
        from_attributes = True

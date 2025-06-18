from pydantic import BaseModel


class PatientBase(BaseModel):
    name: str
    age: str
    gender: str


class PatientCreate(PatientBase):
    pass


class PatientOut(PatientBase):
    id: str

    class Config:
        from_attributes = True

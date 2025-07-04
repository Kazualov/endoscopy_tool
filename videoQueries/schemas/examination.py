from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ExaminationCreate(BaseModel):
    patient_id: str
    description: Optional[str] = ""
    custom_path: Optional[str] = ""


class ExaminationResponse(BaseModel):
    id: str
    patient_id: str
    description: Optional[str]
    date: datetime
    video_id: Optional[str]
    folder_path: Optional[str]

    class Config:
        from_attributes = True


from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


class ExaminationCreate(BaseModel):
    patient_id: str
    description: Optional[str] = None  # Changed from "" to None for consistency
    custom_path: Optional[str] = None  # Changed from "" to None


class ExaminationResponse(BaseModel):
    id: str
    patient_id: str
    description: Optional[str] = None
    date: datetime
    video_id: Optional[str] = None  # Explicit default None
    folder_path: str  # Changed to non-optional since it's required in your model

    # Modern Pydantic v2 config (better than class Config)
    model_config = ConfigDict(from_attributes=True)


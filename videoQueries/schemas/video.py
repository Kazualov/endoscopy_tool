from pydantic import BaseModel
from typing import Optional


class VideoMetadata(BaseModel):
    patient_id: str
    description: Optional[str]
    timestamp: Optional[str]
    notes: Optional[str]

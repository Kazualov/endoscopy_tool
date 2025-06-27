from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class DetectionResponse(BaseModel):
    examination_id: str
    timestamp: float
    x1: int
    y1: int
    x2: int
    y2: int
    label: str
    confidence: float

    class Config:
        orm_mode = True
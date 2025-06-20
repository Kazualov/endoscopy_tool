from pydantic import BaseModel
from datetime import datetime


class ScreenshotResponse(BaseModel):
    screenshot_id: int
    exam_id: str  # заменено с video_id
    filename: str
    file_path: str
    created_at: datetime

    class Config:
        from_attributes = True


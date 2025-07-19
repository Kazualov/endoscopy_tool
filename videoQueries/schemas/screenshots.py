from typing import Optional

from pydantic import BaseModel
from datetime import datetime


class ScreenshotResponse(BaseModel):
    screenshot_id: int
    exam_id: str  # заменено с video_id
    filename: str
    file_path: str
    timestamp_in_video: str
    timestamp_in_seconds: int
    created_at: Optional[datetime] = None  # Make it optional
    annotated_filename: str | None = None
    annotated_file_path: str | None = None
    class Config:
        from_attributes = True


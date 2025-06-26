from fastapi import UploadFile, File, APIRouter
from fastapi.responses import JSONResponse
import cv2
import numpy as np

router = APIRouter()

previous_frame = None
freeze_count = 1
FREEZE_THRESHOLD = 3  # number of consecutive identical frames to detect freeze


def frames_are_equal(frame1_bytes, frame2_bytes):
    # Decode bytes to images
    nparr1 = np.frombuffer(frame1_bytes, np.uint8)
    img1 = cv2.imdecode(nparr1, cv2.IMREAD_GRAYSCALE)

    nparr2 = np.frombuffer(frame2_bytes, np.uint8)
    img2 = cv2.imdecode(nparr2, cv2.IMREAD_GRAYSCALE)

    if img1 is None or img2 is None:
        return False

    # Simple pixel difference
    diff = cv2.absdiff(img1, img2)
    non_zero_count = np.count_nonzero(diff)
    return non_zero_count < 100  # threshold of pixel difference


@router.post("/frame/")
async def receive_frame(frame: UploadFile = File(...)):
    global previous_frame, freeze_count

    current_bytes = await frame.read()

    if previous_frame is None:
        previous_frame = current_bytes
        freeze_count = 0
        return JSONResponse({"freeze": False})

    if frames_are_equal(previous_frame, current_bytes):
        freeze_count += 1
    else:
        freeze_count = 0

    previous_frame = current_bytes

    freeze_detected = freeze_count >= FREEZE_THRESHOLD
    return JSONResponse({"freeze": freeze_detected})
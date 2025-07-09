from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
from videoQueries.utils.freeze_detector import FreezeDetector

router = APIRouter()
detector = FreezeDetector(camera_source=0)


@router.post("/start-freeze-detection")
def start_freeze_detection():
    if not detector.is_running():
        detector.start()
    return {"status": "started"}


@router.post("/stop-freeze-detection")
def stop_freeze_detection():
    if detector.is_running():
        detector.stop()
    return {"status": "stopped"}


@router.get("/freeze-status")
def get_status():
    return {
        "freeze": bool(detector.freeze_detected),
        "screenshot": detector.last_screenshot
    }


@router.websocket("/ws/freeze")
async def websocket_freeze(websocket: WebSocket):
    await websocket.accept()
    detector.register_client(websocket)
    try:
        while True:
            await websocket.receive_text()  # Keep connection alive
    except WebSocketDisconnect:
        detector.unregister_client(websocket)
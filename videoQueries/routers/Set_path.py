from fastapi import FastAPI, APIRouter, Form, Request
router = APIRouter()
@router.post("/config/set-storage-path/")
def set_storage_path(path: str = Form(...), request: Request = None):
    request.app.state.base_storage_path = path
    return {"message": "Путь успешно установлен", "path": path}

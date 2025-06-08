from fastapi import FastAPI
from routers import video
import uvicorn
from database import init_db

app = FastAPI()
app.include_router(video.router)


@app.on_event("startup")
def startup_event():
    init_db()


if __name__ == "__main__":
    uvicorn.run("main:app", reload=True)

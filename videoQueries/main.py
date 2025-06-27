from fastapi import FastAPI
from videoQueries.database import init_db
from videoQueries.routers import video
from fastapi.middleware.cors import CORSMiddleware
from videoQueries.routers import patient
from videoQueries.routers import Screenshots
from videoQueries.routers import Examination
from videoQueries.routers import Set_path
from contextlib import asynccontextmanager
from videoQueries.routers import Detection
import uvicorn
#import voiceCommand


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    app.state.base_storage_path = ""
    yield
    # Shutdown (optional): clean up resources here if needed

app = FastAPI(lifespan=lifespan)

# Routers
app.include_router(video.router)
app.include_router(patient.router)
app.include_router(Examination.router)
app.include_router(Screenshots.router)
app.include_router(Detection.router)
app.include_router(Set_path.router)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=False)


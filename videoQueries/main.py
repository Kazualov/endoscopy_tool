from fastapi import FastAPI
from contextlib import asynccontextmanager
from videoQueries.database import init_db
from videoQueries.routers import video, patient, Examination
from fastapi.middleware.cors import CORSMiddleware

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    yield
    # Shutdown (optional): clean up resources here if needed

app = FastAPI(lifespan=lifespan)

# Routers
app.include_router(video.router)
app.include_router(patient.router)
app.include_router(Examination.router)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", reload=True)

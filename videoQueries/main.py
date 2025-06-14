from fastapi import FastAPI
from routers import video
import uvicorn
from database import init_db
from fastapi.middleware.cors import CORSMiddleware
from videoQueries.routers import patient


app = FastAPI()
app.include_router(video.router)
app.include_router(patient.router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # use ["http://localhost:3000"] for specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    init_db()

if __name__ == "__main__":
    uvicorn.run("main:app", reload=True)

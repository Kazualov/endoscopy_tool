from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
import os
import sys
Base = declarative_base()

def get_app_path():
    if getattr(sys, 'frozen', False):
        # Если запущено как собранный exe
        return sys._MEIPASS
    return os.path.dirname(os.path.abspath(__file__))

app_path = get_app_path()
db_path = os.path.join(app_path, "Base.db")
DATABASE_URL = f"sqlite:///{db_path}"


engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)  # Autoflush automatically refreshes data


def clear_tables():
    Base.metadata.drop_all(engine)


# Create tables
def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

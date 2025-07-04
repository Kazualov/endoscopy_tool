import pytest
from fastapi.testclient import TestClient
from main import app
from database import Base, engine

@pytest.fixture(scope="module")
def client():
    # Создаём все таблицы (если их нет)
    Base.metadata.create_all(bind=engine)

    with TestClient(app) as c:
        yield c

    # Очистка (опционально)
    Base.metadata.drop_all(bind=engine)

import pytest
from fastapi.testclient import TestClient
from videoQueries.main import app
from videoQueries.database import Base, engine

@pytest.fixture(scope="module")
def client():
    # Создаём все таблицы (если их нет)
    Base.metadata.create_all(bind=engine)

    with TestClient(app) as c:
        yield c

    # Очистка (опционально)
    Base.metadata.drop_all(bind=engine)

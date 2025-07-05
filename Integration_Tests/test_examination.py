import uuid
from conftest import client
from pathlib import Path

# Get the correct path to test files
TEST_FILES_DIR = Path(__file__).parent
SAMPLE_MP4 = TEST_FILES_DIR / "sample.mp4"
SAMPLE_JPG = TEST_FILES_DIR / "sample.jpg"

def test_create_examination_success(client):
    """Test successful examination creation"""
    # Create a patient first
    response = client.post("/patients/", json={"id": "123123123"})
    patient_id = response.json()

    # Test examination creation
    response = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "Test examination",
    })

    assert response.status_code == 200
    assert response.json()["patient_id"] == patient_id

def test_create_examination_invalid_patient(client):
    """Test examination creation with invalid patient ID"""
    fake_id = str(uuid.uuid4())
    response = client.post("/examinations/", json={
        "patient_id": fake_id,
        "description": "Invalid"
    })

    assert response.status_code == 404
    # Update to match your API's language (English or Russian)
    assert response.json()["detail"] == "Пациент не найден"  # Russian version
    # OR: assert response.json()["detail"] == f"Patient with id={fake_id} was not found"  # English version

def test_upload_video_success(client):
    """Test successful video upload"""
    # Create patient and examination
    patient_id = client.post("/patients/", json={"id": "100101010"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id, 
        "description": "Examination"
    }).json()

    # Upload the video using correct path
    assert SAMPLE_MP4.exists(), f"Test video file missing at {SAMPLE_MP4}"
    with open(SAMPLE_MP4, "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        response = client.post(f"/examinations/{exam['id']}/video/", files=files)

    assert response.status_code == 200
    assert "video_id" in response.json()

def test_upload_video_twice(client):
    """Test duplicate video upload rejection"""
    patient_id = client.post("/patients/", json={"id": "229299292"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id, 
        "description": "Repeat test"
    }).json()

    # First upload (should succeed)
    assert SAMPLE_MP4.exists(), f"Test video file missing at {SAMPLE_MP4}"
    with open(SAMPLE_MP4, "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        client.post(f"/examinations/{exam['id']}/video/", files=files)

    # Second upload (should fail)
    with open(SAMPLE_MP4, "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        response = client.post(f"/examinations/{exam['id']}/video/", files=files)

    assert response.status_code == 400

def test_get_examination_by_id(client):
    """Test examination retrieval by ID"""
    patient_id = client.post("/patients/", json={"id": "554433"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "get exam"
    }).json()

    response = client.get(f"/examinations/{exam['id']}/")
    assert response.status_code == 200
    assert response.json()["id"] == exam["id"]
    assert response.json()["patient_id"] == patient_id

def test_delete_examination(client):
    """Test examination deletion"""
    patient_id = client.post("/patients/", json={"id": "7654321"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "to be deleted"
    }).json()

    # Delete examination
    response = client.delete(f"/examinations/{exam['id']}/")
    assert response.status_code == 200

    # Verify examination no longer exists
    response = client.get(f"/examinations/{exam['id']}/")
    assert response.status_code == 404

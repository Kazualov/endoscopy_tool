import uuid
from conftest import client
from pathlib import Path
#We check that the API returns the correct response when creating an inspection
def test_create_examination_success(client):
    #Creation of a patient preliminary
    response = client.post("/patients/", json={"id": "123123123"})
    patient_id = response.json()

    #Test of examinations creation
    response = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "Test examination",
    })

    assert response.status_code == 200
    assert response.json()["patient_id"] == patient_id

#We check that the API returns an appropriate error when the patient ID is invalid
def test_create_examination_invalid_patient(client):
    fake_id = str(uuid.uuid4())
    response = client.post("/examinations/", json={
        "patient_id": fake_id,
        "description": "Invalid"
    })

    assert response.status_code == 404
    assert response.json()["detail"] == f"Patient with id={fake_id} was not found"

#We check that everything works correctly when uploading a video for inspection
def test_upload_video_success(client):
    #Create patient and examination
    patient_id = client.post("/patients/", json={"id": "100101010"}).json()
    exam = client.post("/examinations/", json={"patient_id": patient_id, "description": "Examination"}).json()

    # Uploading the video
    with open("/Integration_Tests/sample.mp4", "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        response = client.post(f"/examinations/{exam['id']}/video/", files=files)

    assert response.status_code == 200
    assert "video_id" in response.json()

#We check that everything works correctly and gives an error when
# trying to upload a video twice for the same inspection
def test_upload_video_twice(client):
    patient_id = client.post("/patients/", json={"id": "229299292"}).json()
    exam = client.post("/examinations/", json={"patient_id": patient_id, "description": "Repeat test"}).json()

    test_files_dir = Path(__file__).parent / "test_files"
    with open(test_files_dir / "sample.mp4", "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        client.post(f"/examinations/{exam['id']}/video/", files=files)

    test_files_dir = Path(__file__).parent / "test_files"
    with open(test_files_dir / "sample.mp4", "rb") as f:
        files = {"file": ("sample.mp4", f, "video/mp4")}
        response = client.post(f"/examinations/{exam['id']}/video/", files=files)

    assert response.status_code == 400

def test_get_examination_by_id(client):
    patient_id = client.post("/patients/", json={"id": "554433"}).json()
    exam = client.post("/examinations/", json={"patient_id": patient_id, "description": "get exam"}).json()

    response = client.get(f"/examinations/{exam['id']}/")
    assert response.status_code == 200
    assert response.json()["id"] == exam["id"]
    assert response.json()["patient_id"] == patient_id

def test_delete_examination(client):
    patient_id = client.post("/patients/", json={"id": "7654321"}).json()
    exam = client.post("/examinations/", json={"patient_id": patient_id, "description": "to be deleted"}).json()

    # Удаляем осмотр
    response = client.delete(f"/examinations/{exam['id']}/")
    assert response.status_code == 200

    # Проверка, что осмотр больше не существует
    response = client.get(f"/examinations/{exam['id']}/")
    assert response.status_code == 404


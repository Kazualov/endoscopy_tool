from conftest import client

#We check that everything works correctly when uploading screenshots of inspections
def test_upload_screenshot(client):
    patient_id = client.post("/patients/", json={"id": "2121212"}).json()
    exam = client.post("/examinations/", json={"patient_id": patient_id, "description": "screenshot"}).json()

    with open("/Integration_Tests/sample.jpg", "rb") as f:
        files = {"file": ("sample.jpg", f, "image/jpg")}
        response = client.post(f"/exams/{exam['id']}/upload_screenshot/", files=files)

    assert response.status_code == 200
    assert "screenshot_id" in response.json()

from pathlib import Path
import os

from pathlib import Path

def test_upload_screenshot_and_annotated_version(client):
    # Step 1: Create patient and examination
    patient_id = client.post("/patients/", json={"id": "123456"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "Test upload screenshot"
    }).json()
    exam_id = exam["id"]

    # Step 2: Upload screenshot (with timestamp)
    screenshot_image_path = Path("/Integration_Tests/sample.mp4")
    assert screenshot_image_path.exists(), "Screenshot test image not found."

    with open(screenshot_image_path, "rb") as f:
        files = {"file": ("annotated_sample.jpg", f, "image/jpeg")}
        data = {"timestamp_in_video": "00:00:05"}
        upload_response = client.post(
            f"/exams/{exam_id}/upload_screenshot/",
            files=files,
            data=data
        )
        assert upload_response.status_code == 200, upload_response.text
        screenshot_id = upload_response.json()["screenshot_id"]

    # Step 3: Upload annotated version for the same screenshot
    with open(screenshot_image_path, "rb") as f:
        files = {"annotated_file": ("annotated_sample.jpg", f, "image/jpeg")}
        response = client.post(f"/screenshots/{screenshot_id}/upload_annotated/", files=files)

    # Step 4: Validate response
    assert response.status_code == 200
    data = response.json()
    assert "annotated_filename" in data
    assert "file_path" in data
    assert data["annotated_filename"].endswith("_annotated.jpg")

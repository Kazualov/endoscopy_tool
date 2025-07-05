from pathlib import Path
from conftest import client

# Define test file paths relative to this test file
TEST_DIR = Path(__file__).parent
SAMPLE_JPG = TEST_DIR / "sample.jpg"
SAMPLE_MP4 = TEST_DIR / "sample.mp4"

def test_upload_screenshot(client):
    """Test successful screenshot upload"""
    # Verify test file exists
    assert SAMPLE_JPG.exists(), f"Test image missing at {SAMPLE_JPG}"
    
    # Create test data
    patient_id = client.post("/patients/", json={"id": "2121212"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "screenshot"
    }).json()

    # Upload screenshot
    with open(SAMPLE_JPG, "rb") as f:
        files = {"file": ("sample.jpg", f, "image/jpeg")}  # Fixed content-type
        response = client.post(
            f"/exams/{exam['id']}/upload_screenshot/", 
            files=files
        )

    # Verify response
    assert response.status_code == 200, response.text
    assert "screenshot_id" in response.json()

def test_upload_screenshot_and_annotated_version(client):
    """Test uploading both original and annotated screenshot"""
    # Verify test files exist
    assert SAMPLE_MP4.exists(), f"Test video missing at {SAMPLE_MP4}"
    
    # Create test data
    patient_id = client.post("/patients/", json={"id": "123456"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "Test upload screenshot"
    }).json()
    exam_id = exam["id"]

    # Upload initial screenshot
    with open(SAMPLE_MP4, "rb") as f:
        files = {"file": ("annotated_sample.jpg", f, "image/jpeg")}
        data = {"timestamp_in_video": "00:00:05"}
        upload_response = client.post(
            f"/exams/{exam_id}/upload_screenshot/",
            files=files,
            data=data
        )
        assert upload_response.status_code == 200, upload_response.text
        screenshot_id = upload_response.json()["screenshot_id"]

    # Upload annotated version
    with open(SAMPLE_MP4, "rb") as f:
        files = {"annotated_file": ("annotated_sample.jpg", f, "image/jpeg")}
        response = client.post(
            f"/screenshots/{screenshot_id}/upload_annotated/", 
            files=files
        )

    # Verify response
    assert response.status_code == 200, response.text
    data = response.json()
    assert all(key in data for key in ["annotated_filename", "file_path"])
    assert data["annotated_filename"].endswith("_annotated.jpg")

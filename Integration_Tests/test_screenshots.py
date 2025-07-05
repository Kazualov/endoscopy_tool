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

    # Upload screenshot with required timestamp
    with open(SAMPLE_JPG, "rb") as f:
        response = client.post(
            f"/exams/{exam['id']}/upload_screenshot/",
            files={"file": ("sample.jpg", f, "image/jpeg")},
            data={"timestamp_in_video": "00:00:01"}  # Added required field
        )

    # Verify response
    assert response.status_code == 200, response.text
    response_data = response.json()
    assert "screenshot_id" in response_data
    assert "filename" in response_data  # Matches endpoint response

def test_upload_screenshot_and_annotated_version(client):
    """Test uploading both original and annotated screenshot"""
    # Verify test files exist
    assert SAMPLE_JPG.exists(), f"Test image missing at {SAMPLE_JPG}"
    
    # Create test data
    patient_id = client.post("/patients/", json={"id": "123456"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "Test upload screenshot"
    }).json()

    # Upload initial screenshot (using JPG)
    with open(SAMPLE_JPG, "rb") as f:
        response = client.post(
            f"/exams/{exam['id']}/upload_screenshot/",
            files={"file": ("screenshot.jpg", f, "image/jpeg")},
            data={"timestamp_in_video": "00:00:05"}
        )
        assert response.status_code == 200, response.text
        screenshot_id = response.json()["screenshot_id"]

    # Upload annotated version (using same JPG)
    with open(SAMPLE_JPG, "rb") as f:
        response = client.post(
            f"/screenshots/{screenshot_id}/upload_annotated/",
            files={"annotated_file": ("annotated.jpg", f, "image/jpeg")}
        )

    # Verify response matches endpoint implementation
    assert response.status_code == 200, response.text
    response_data = response.json()
    assert "annotated_filename" in response_data
    assert response_data["annotated_filename"].endswith("_annotated.jpg")

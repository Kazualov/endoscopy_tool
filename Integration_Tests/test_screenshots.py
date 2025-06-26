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
import os

def test_process_video_success(client):
    # Step 1: Create patient and examination
    patient_id = client.post("/patients/", json={"id": "101010"}).json()
    exam = client.post("/examinations/", json={
        "patient_id": patient_id,
        "description": "For detection"
    }).json()

    # Step 2: Upload video for the examination
    video_filename = "sample.mp4"
    video_path_local = f"Integration_Tests/sample.mp4"

    with open(video_path_local, "rb") as f:
        files = {"file": (video_filename, f, "video/mp4")}
        upload_response = client.post(f"/examinations/{exam['id']}/video/", files=files)
        assert upload_response.status_code == 200


    # Step 4: Send request to process video
    response = client.post(
        f"/examinations/{exam['id']}/process_video/",
        params={"video_path": video_path_local}
    )

    # Step 5: Validate the response
    assert response.status_code == 200
    data = response.json()
    assert "annotated_video_filename" in data
    assert "annotated_video_path" in data
    assert "detections" in data
    assert isinstance(data["detections"], list)

def test_process_video_invalid_exam(client):
    fake_exam_id = "not-real-id"
    response = client.post(f"/examinations/{fake_exam_id}/process_video/?video_path=videos/fake/sample.mp4")
    assert response.status_code == 404
    assert response.json()["detail"] == "Осмотр не найден"


# User Acceptance Tests

This file contains both old and newly introduced user acceptance tests, based on the acceptance criteria discussed with the customer.  
Each test links to the related acceptance criteria (AC) for traceability and clarity.

---

## Old Acceptance Tests

### Test 1: Take a screenshot using voice input after loading a video

**Steps:**
1. Load any video from your computer (preferably endoscopic findings).
2. Allow access to the microphone if requested.
3. Say: "screenshot".
4. A screenshot should be saved in the original document and displayed on the left with a timecode.

**Linked acceptance criteria:**
[Voice command triggers screenshot](https://github.com/Kazualov/endoscopy_tool/issues/43)

---

### Test 2: Record a real-time video from the endoscope and check that it is saved correctly

**Steps:**
1. Click the "Start recording" button.
2. Click the "Stop recording" button — the recorded video will open automatically.
3. Go to the list of recordings.
4. Find and open the video you just recorded.

**Ensure:**
- The video plays normally.
- The quality is good (not blurry or jerky).
- The video is linked to the correct examination.
- The recording date/time and duration are displayed correctly.

**Linked acceptance criteria:**
[Live-stream recording](https://github.com/Kazualov/endoscopy_tool/issues/44)

---

### Test 3: Open a screenshot and make visual notes on it

**Steps:**
1. Take a screenshot while watching or streaming a video.
2. Open the screenshot panel and click on one.
3. Ensure the editing drawer opens on the side.

**Use at least one tool:**
- Draw any line.
- Select an area.
- Click “Save” and close the panel.

**Linked acceptance criteria:**
[Drawer interface for screenshot](https://github.com/Kazualov/endoscopy_tool/issues/42)

---

### Test 4: Draw a circle and an arrow on a screenshot

**Steps:**
1. Open any previously taken screenshot.
2. In the editing panel, select the “Circle” tool.
3. Click and drag to draw a circle.
4. Then select the “Arrow” tool and point to another part of the image.
5. Press “Save”.
6. Reopen the same screenshot.

**Ensure:**
- The circle and arrow are still visible.
- You can select, move or delete them.

**Linked acceptance criteria:**
[Add circle and arrow to the screenshots editor](https://github.com/Kazualov/endoscopy_tool/issues/52)

---

### Test 5: Watch a video and observe detected anomalies automatically highlighted on screen

**Steps:**
1. Open any previously saved endoscopic video.
2. Start playback.
3. Observe whether:
   - A red or highlighted square appears when an anomaly is detected.
   - The square disappears when there's no anomaly.
   - The square reappears with new anomalies.
4. Pause the video during detection and confirm the bounding box remains visible on the paused frame.

**Linked acceptance criteria:**
[Connect anomaly recognition model with the app](https://github.com/Kazualov/endoscopy_tool/issues/41)

---

## New Acceptance Tests

### Test 6: Display anomaly markers on the video timeline and enable navigation

**Steps:**
1. Open a video that has known anomaly detection results.
2. Look at the timeline bar below the video.
3. Observe whether one or more highlighted segments are displayed on the timeline.
4. Hover over one of the segments.

**Verify:**
- A tooltip or label appears
- Clicking on the segment seeks the video to the anomaly start
- Video playback continues correctly from that position
- The highlighted timeline segments match the real timestamps (check model output if needed)

**Linked acceptance criteria:**
[Add area on the video timeline indicating anomalies detected by model]([https://github.com/yourteam/repo/issues/XYZ](https://github.com/Kazualov/endoscopy_tool/issues/70))

--- 

### Test 7: View the full speech transcript for a patient session in the application

**Steps:**
1. Open the application and go to the list of past patient sessions.
2. Select a session where voice commands or dictation were used.
3. Click the "Transcript" or "Speech history" tab in the session screen.

**Verify:**
- You can see all the spoken phrases in text format.
- Each phrase includes a timestamp showing when it was said.
- The text accurately reflects what was said during the session.
- You can scroll, copy, or export the transcript if needed (e.g., to patient record or summary).

**Linked acceptance criteria:**
[Create functionality to get all the speech](https://github.com/Kazualov/endoscopy_tool/issues/61)

---

# TO BE REMOVED FROM HERE

import cv2
import numpy as np
import time
import os
import threading

class FreezeDetector:
    def __init__(self, stream_source=0, screenshot_dir="screenshots",
                 freeze_frame_threshold=3, pixel_diff_threshold=1500):
        self.stream_source = stream_source
        self.screenshot_dir = screenshot_dir
        os.makedirs(self.screenshot_dir, exist_ok=True)

        self.freeze_frame_threshold = freeze_frame_threshold
        self.pixel_diff_threshold = pixel_diff_threshold

        self.cap = cv2.VideoCapture(self.stream_source)
        self.prev_gray = None
        self.freeze_count = 0
        self.freeze_cooldown = 0

        self.running = False

    def frames_are_similar(self, gray1, gray2):
        diff = cv2.absdiff(gray1, gray2)
        non_zero = np.count_nonzero(diff)
        return non_zero < self.pixel_diff_threshold

    def save_screenshot(self, frame):
        timestamp = int(time.time() * 1000)
        filename = os.path.join(self.screenshot_dir, f"freeze_{timestamp}.jpg")
        cv2.imwrite(filename, frame)
        print(f"[✓] Screenshot saved: {filename}")

    def start(self):
        self.running = True
        threading.Thread(target=self.run, daemon=True).start()
        print("📹 Freeze detection thread started")

    def stop(self):
        self.running = False
        self.cap.release()
        print("🛑 Freeze detection stopped")

    def run(self):
        while self.running:
            ret, frame = self.cap.read()
            if not ret:
                continue

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            if self.prev_gray is not None:
                if self.frames_are_similar(self.prev_gray, gray):
                    self.freeze_count += 1
                else:
                    self.freeze_count = 0

                if self.freeze_count >= self.freeze_frame_threshold and self.freeze_cooldown == 0:
                    print("❄️ Freeze detected! Capturing screenshot...")
                    self.save_screenshot(frame)
                    self.freeze_cooldown = 30  # ~1 second cooldown

            self.prev_gray = gray

            if self.freeze_cooldown > 0:
                self.freeze_cooldown -= 1

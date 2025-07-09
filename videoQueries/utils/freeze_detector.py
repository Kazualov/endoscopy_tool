import cv2
import threading
import time
import base64
import numpy as np
from typing import List
from starlette.websockets import WebSocket


class FreezeDetector:
    def __init__(self, camera_source=0, threshold=5.0, interval=1.0):
        self.camera_source = camera_source
        self.threshold = threshold
        self.interval = interval
        self.threshold = threshold
        self.running = False
        self.freeze_detected = None  # Track last status
        self.last_screenshot = None
        self.lock = threading.Lock()
        self.thread = None
        self.clients: List[WebSocket] = []

    def start(self):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()

    def is_running(self):
        return self.running

    def register_client(self, websocket: WebSocket):
        self.clients.append(websocket)

    def unregister_client(self, websocket: WebSocket):
        if websocket in self.clients:
            self.clients.remove(websocket)

    def _broadcast(self, message: dict):
        to_remove = []
        for ws in self.clients:
            try:
                import asyncio
                asyncio.create_task(ws.send_json(message))
            except Exception:
                to_remove.append(ws)

        for ws in to_remove:
            self.unregister_client(ws)

    def _run(self):
        cap = cv2.VideoCapture(self.camera_source)
        if not cap.isOpened():
            self.running = False
            return

        ret, prev_frame = cap.read()
        if not ret:
            self.running = False
            return

        while self.running:
            time.sleep(self.interval)
            ret, curr_frame = cap.read()
            if not ret:
                break

            frozen_now = self._is_frozen(prev_frame, curr_frame)
            if frozen_now:
                screenshot = self._encode_frame(curr_frame)
            else:
                screenshot = None

            with self.lock:
                # Only broadcast if freeze state changed
                if frozen_now != self.freeze_detected:
                    self.freeze_detected = frozen_now
                    self.last_screenshot = screenshot
                    self._broadcast({
                        "freeze": bool(frozen_now),
                        "screenshot": screenshot
                    })

            prev_frame = curr_frame

        cap.release()

    def _is_frozen(self, frame1, frame2):
        diff = cv2.absdiff(frame1, frame2)
        non_zero = np.count_nonzero(diff)
        total = frame1.size
        percent_diff = (non_zero / total) * 100
        return percent_diff < self.threshold

    def _encode_frame(self, frame):
        _, buffer = cv2.imencode('.jpg', frame)
        return base64.b64encode(buffer).decode('utf-8')

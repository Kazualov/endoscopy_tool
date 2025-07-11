import cv2
import threading
import time
import base64
import numpy as np
from typing import List
from starlette.websockets import WebSocket
import asyncio
import queue
from skimage.metrics import structural_similarity as ssim


class FreezeDetector:
    def __init__(self, camera_source=0, threshold=1.0, interval=0.5):
        self.camera_source = camera_source
        self.threshold = threshold
        self.interval = interval
        self.running = False
        self.freeze_detected = False  # Track last status
        self.last_screenshot = None
        self.lock = threading.Lock()
        self.thread = None
        self.clients: List[WebSocket] = []
        self.message_queue = queue.Queue()
        self.event_loop = None

    def start(self):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

        # Start message dispatcher thread
        threading.Thread(target=self._dispatch_messages, daemon=True).start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()

    def is_running(self):
        return self.running

    def register_client(self, websocket: WebSocket):
        with self.lock:
            self.clients.append(websocket)
            if self.event_loop is None:
                self.event_loop = asyncio.get_event_loop()

    def unregister_client(self, websocket: WebSocket):
        with self.lock:
            if websocket in self.clients:
                self.clients.remove(websocket)

    def _broadcast(self, message: dict):
        # Put message in queue instead of sending directly
        self.message_queue.put(message)

    def _dispatch_messages(self):
        while self.running:
            try:
                message = self.message_queue.get(timeout=0.1)
                if not self.clients or self.event_loop is None:
                    continue

                # Create a copy of clients to avoid threading issues
                with self.lock:
                    clients = self.clients.copy()

                # Schedule coroutines to run in the event loop
                for ws in clients:
                    try:
                        asyncio.run_coroutine_threadsafe(
                            self._safe_send(ws, message),
                            self.event_loop
                        )
                    except Exception:
                        self.unregister_client(ws)

            except queue.Empty:
                continue

    async def _safe_send(self, ws: WebSocket, message: dict):
        try:
            await ws.send_json(message)
        except Exception:
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
        gray1 = cv2.cvtColor(frame1, cv2.COLOR_BGR2GRAY)
        gray2 = cv2.cvtColor(frame2, cv2.COLOR_BGR2GRAY)
        score, _ = ssim(gray1, gray2, full=True)
        return score > 0.97  # tune threshold

    def _encode_frame(self, frame):
        _, buffer = cv2.imencode('.jpg', frame)
        return base64.b64encode(buffer).decode('utf-8')
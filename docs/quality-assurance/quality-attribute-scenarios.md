## Performance Efficiency

### Time Behaviour
**Why it's important:**  
Doctors rely on fast response time when using voice commands during live endoscopy. Delays can reduce efficiency and impact patient care.

#### Voice-triggered screenshot during procedure
**Scenario:**  
- **Source**: Doctor  
- **Stimulus**: Doctor says a voice command to make a screenshot  
- **Artifact**: Voice recognition model, API, Flutter app  
- **Environment**: During endoscopy procedure  
- **Response**: App processes command and takes screenshot  
- **Response Measure**: Screenshot created in less than 2 seconds

**Execution method:**  
Run the app during a mock endoscopy session. Use a stopwatch or built-in logging to measure time from voice input to screenshot saved.

---

## Usability

### Operability
**Why it's important:**  
Doctors must interact with the system without touching the screen. Hands-free operation improves hygiene and usability.

#### Voice-triggered dialog opening
**Scenario:**  
- **Source**: Doctor  
- **Stimulus**: Doctor starts creating a new patient examination  
- **Artifact**: Vosk, Flutter app  
- **Environment**: Normal clinic environment  
- **Response**: App opens a registration dialog  
- **Response Measure**: Success rate of voice-triggered dialog opening > 95%

**Execution method:**  
Simulate user tests with multiple doctors. Record success/failure rate of opening dialogs via voice.

---

## Flexibility

### Scalability
**Why it's important:**  
The app handles large video data. If the system can’t scale or inform the user, it may crash or lose data.

#### Storage overload handling
**Scenario:**  
- **Source**: Endoscopy app  
- **Stimulus**: Storage exceeds 95% capacity  
- **Artifact**: App and backend storage logic  
- **Environment**: Production environment with full disk  
- **Response**: Notify user and prevent crash  
- **Response Measure**: Notification shown within 3 seconds, at least 1 GB freed before next recording

**Execution method:**  
Simulate full storage in staging. Check logs and UI feedback time.

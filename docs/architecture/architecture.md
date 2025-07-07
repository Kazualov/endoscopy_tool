### Static view

The system is composed of several loosely-coupled, highly cohesive components:

![Component Diagram](docs/architecture/static-view/component-diagram.png)

- **Frontend (GUI)**: Displays the user interface, handles user actions.
- **Backend**: Coordinates sessions, voice commands, AI detection, and storage.
- **AI Detection Module**: Analyzes videos to detect polyps.
- **Voice Processor**: Interprets commands using Vosk speech-to-text.
- **Screenshot Drawer**: Stores and displays doctor-marked frames.
- **File Storage**: Saves session videos and screenshots locally.
- **Metadata DB**: Stores structured information about sessions and detections.

> Components interact via internal calls, maintaining separation of concerns and enabling easy updates and testing. High cohesion and modularity ensure maintainability.

### Dynamic view

The following sequence diagram represents the process when a doctor uploads an endoscopy video for analysis:

![Sequence Diagram](docs/architecture/dynamic-view/sequence-diagram.png)

### Deployment view

The application is deployed as a **standalone desktop app** on the doctor’s PC. It includes a graphical user interface (GUI), an embedded backend with AI detection logic, voice command processing (using Vosk), local video/screenshot storage, and a local database managed with SQLAlchemy (typically using SQLite).

![Deployment Diagram](docs/architecture/deployment-view/deployment-diagram.png)

- All modules run locally within a single process or bundled executable.
- Data privacy is preserved by avoiding any cloud or network interaction.
- The system is updated via installer, requiring no advanced setup or configuration.

> This deployment choice simplifies usage in clinical environments where network connectivity may be restricted and data confidentiality is critical.

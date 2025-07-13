<!-- Improved README inspired by Best-README-Template -->

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/Kazualov/endoscopy_tool">
    <img src="logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">EndoAssist</h3>

  <p align="center">
    AI-Powered Endoscopy Session Assistant
    <br />
    <a href="https://github.com/Kazualov/endoscopy_tool/docs"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/Kazualov/endoscopy_tool">View Demo</a>
    ·
    <a href="https://github.com/Kazualov/endoscopy_tool/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    ·
    <a href="https://github.com/Kazualov/endoscopy_tool/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

[![EndoAssist Screen Shot][product-screenshot]](https://github.com/Kazualov/endoscopy_tool)

EndoAssist is a standalone desktop application that revolutionizes endoscopy procedures by providing AI-powered assistance to medical professionals. The system combines real-time polyp detection, voice control capabilities, and comprehensive session management to enhance diagnostic accuracy and streamline medical documentation.

Here's why EndoAssist stands out:
* **Real-time AI Detection**: Advanced YOLOv8-based polyp detection during live procedures
* **Voice Control**: Hands-free operation for capturing screenshots and controlling recordings
* **Comprehensive Documentation**: Automatic session recording and annotation capabilities
* **Offline Operation**: Complete functionality without internet dependency for maximum privacy and reliability

EndoAssist bridges the gap between cutting-edge AI technology and practical clinical workflow, ensuring that healthcare professionals can leverage advanced detection capabilities without disrupting their established procedures.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

This section lists the major frameworks and technologies used to build EndoAssist:

* [![Python][Python.py]][Python-url]
* [![FastAPI][FastAPI.dev]][FastAPI-url]
* [![Flutter][Flutter.dev]][Flutter-url]
* [![SQLite][SQLite.org]][SQLite-url]
* [![OpenCV][OpenCV.org]][OpenCV-url]
* [![YOLOv8][YOLOv8.com]][YOLOv8-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

To get EndoAssist up and running on your local machine, follow these simple steps.

### Prerequisites

Before installing EndoAssist, ensure your system meets the following requirements:

* **Operating System**: Windows 10+ or macOS 10.15+
* **RAM**: Minimum 8GB, recommended 16GB
* **Storage**: At least 5GB free space
* **Hardware**: Compatible camera/endoscope device

### Installation

1. **Download the Installation Package**
   
   Visit our distribution server:
   ```
   https://disk.yandex.ru/d/xsm4Hyo1oVTSWA/builds
   ```

2. **Select Your Operating System**
   
   Choose the appropriate folder for your system (Windows or macOS)

3. **Install Backend Service**
   
   Download and extract `dist.zip`:
   ```bash
   # Extract the archive
   unzip dist.zip
   cd dist/
   
   # Run the backend service
   ./main_executable
   ```
   
   **Important**: Keep this terminal window open during application use

4. **Install Main Application**
   
   Download and extract the main application archive:
   ```bash
   # Extract the application
   unzip endoscopy_tool.zip
   cd endoscopy_tool/
   
   # Launch the application
   ./endoskopy_tool.exe  # Windows
   # or
   ./endoskopy_tool      # macOS
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

EndoAssist provides an intuitive workflow for conducting and reviewing endoscopy procedures:

### 🏥 Creating a New Examination

1. Launch the application and click the **➕ Plus** button
2. Fill in the patient information form
3. You'll be automatically directed to the live camera interface

### 🎥 Live Recording with AI Detection

```bash
# Voice commands available during recording:
"Screenshot"  # Captures current frame
"Start recording"  # Begins video recording
"Stop recording"   # Ends video recording
```

* Toggle **"AI On"** to enable real-time polyp detection
* Use voice commands or UI buttons for hands-free operation
* Access drawing tools for immediate annotation

### 📂 Video Upload and Analysis

* Upload pre-recorded videos for AI analysis
* Automatic polyp detection processing
* Frame-by-frame review with detection highlights

_For detailed usage instructions, please refer to the [Documentation](https://github.com/Kazualov/endoscopy_tool/docs)_

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

### ✅ Completed Features

- [x] Patient and examination management
- [x] Real-time video recording and streaming
- [x] Voice-controlled screenshot capture
- [x] YOLOv8-based polyp detection
- [x] Annotation and drawing tools
- [x] FastAPI backend with SQLite storage
- [x] Cross-platform Flutter UI

### 🚀 Upcoming Features

- [ ] **Voice Recording Enhancement**
  - [ ] Doctor's voice recording during procedures
  - [ ] Voice transcript generation
  - [ ] Automated session summaries
- [ ] **UI/UX Improvements**
  - [ ] Enhanced user interface design
  - [ ] Improved workflow optimization
  - [ ] Accessibility enhancements
- [ ] **Advanced AI Features**
  - [ ] Multi-class anomaly detection
  - [ ] Predictive analytics
  - [ ] Integration with additional AI models

See the [open issues](https://github.com/Kazualov/endoscopy_tool/issues) for a full list of proposed features and known issues.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Resources

* [Kanban Board](https://github.com/Kazualov/endoscopy_tool/blob/main/docs/Contributing.md)
* [Git Workflow](https://github.com/Kazualov/endoscopy_tool/blob/main/docs/Contributing.md)
* [Quality Assurance](https://github.com/Kazualov/endoscopy_tool/blob/main/docs/quality_assurance.md)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Project Maintainer - [@Kazualov](https://github.com/Kazualov)

Project Link: [https://github.com/Kazualov/endoscopy_tool](https://github.com/Kazualov/endoscopy_tool)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

Special thanks to the following resources and contributors that made this project possible:

* [YOLOv8 by Ultralytics](https://github.com/ultralytics/ultralytics)
* [Vosk Speech Recognition](https://alphacephei.com/vosk/)
* [FastAPI Framework](https://fastapi.tiangolo.com/)
* [Flutter Framework](https://flutter.dev/)
* [OpenCV Library](https://opencv.org/)
* [Best README Template](https://github.com/othneildrew/Best-README-Template)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/Kazualov/endoscopy_tool.svg?style=for-the-badge
[contributors-url]: https://github.com/Kazualov/endoscopy_tool/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Kazualov/endoscopy_tool.svg?style=for-the-badge
[forks-url]: https://github.com/Kazualov/endoscopy_tool/network/members
[stars-shield]: https://img.shields.io/github/stars/Kazualov/endoscopy_tool.svg?style=for-the-badge
[stars-url]: https://github.com/Kazualov/endoscopy_tool/stargazers
[issues-shield]: https://img.shields.io/github/issues/Kazualov/endoscopy_tool.svg?style=for-the-badge
[issues-url]: https://github.com/Kazualov/endoscopy_tool/issues
[license-shield]: https://img.shields.io/github/license/Kazualov/endoscopy_tool.svg?style=for-the-badge
[license-url]: https://github.com/Kazualov/endoscopy_tool/blob/main/LICENSE
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/your-linkedin-profile
[product-screenshot]: images/screenshot.png
[Python.py]: https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white
[Python-url]: https://python.org/
[FastAPI.dev]: https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi
[FastAPI-url]: https://fastapi.tiangolo.com/
[Flutter.dev]: https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white
[Flutter-url]: https://flutter.dev/
[SQLite.org]: https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white
[SQLite-url]: https://sqlite.org/
[OpenCV.org]: https://img.shields.io/badge/opencv-%23white.svg?style=for-the-badge&logo=opencv&logoColor=white
[OpenCV-url]: https://opencv.org/
[YOLOv8.com]: https://img.shields.io/badge/YOLOv8-00FFFF?style=for-the-badge&logo=yolo&logoColor=black
[YOLOv8-url]: https://github.com/ultralytics/ultralytics

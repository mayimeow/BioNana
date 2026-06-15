# BioNana 🍌💧

An IoT-based automated extraction system designed to convert agricultural waste (banana pseudostems) into nutrient-rich liquid organic fertilizer. BioNana bridges the gap between hardware engineering and software management, featuring a physical extraction machine controlled by an ESP32 microcontroller, fully synchronized with a modern mobile app.

## ✨ Key Features
* **Automated Extraction Cycle:** Hardware-driven logic that manages the processing and extraction of liquid fertilizer.
* **Smart Sensor Integration:** Utilizes ultrasonic and capacitive liquid sensors for fail-safe tank volume monitoring.
* **Mobile Synchronization:** Real-time monitoring and control of the physical machine via a Flutter-based mobile app.
* **Developer Controls:** Custom firmware bypasses (like "Force Start") built-in for rapid testing and debugging.
* **Cloud Database:** Hybrid local and cloud storage implementation for extreme reliability.

## 🛠️ Tech Stack
* **Mobile Dashboard:** Flutter / Dart
* **Hardware Firmware:** C++ (ESP32 Microcontroller)
* **Backend:** Firebase 
* **Database:** SQLite (Local) & Cloud Firestore

## 🚀 How to Run the Project

This repository contains both the mobile application and the hardware firmware. 

### Running the Mobile App (Flutter)
**1. Clone the repository**
\`\`\`bash
git clone https://github.com/mayimeow/BioNana.git
cd bionana
\`\`\`

**2. Install dependencies**
\`\`\`bash flutter pub get
\`\`\`

**3. Run the app**
\`\`\`bash
flutter run
\`\`\`

*(Note: Ensure you add your own `google-services.json` for Firebase authentication to work).*


---
*Developed by the BioNana Student Research Team.*

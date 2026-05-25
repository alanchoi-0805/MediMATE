# MediMATE: An IoT-Based Medicine Reminder System Using ESP32 and Mobile App

MediMATE is an IoT healthcare ecosystem designed to improve elderly medication adherence. It integrates a physical pillbox with a cross-platform mobile application to track, verify, and log medication events in real time.

## Key Features
- **Smart Hardware Guidance:** ESP32-controlled pillbox with magnetic reed switch sensors, push buttons, an OLED screen, and LED/buzzer alerts.
- **Dual-Role Flutter App:** Customized interfaces for both Patients and Caregivers with 3-language support (EN/BM/CN).
- **Real-Time Cloud Sync:** Instant bidirectional data logging via Firebase Cloud Firestore.

## Repository Structure
- `/hardware_esp32`: C++ source code firmware for the Arduino IDE.
- `/software_flutter`: Dart source code for the Flutter mobile application.

## Tech Stack & Prerequisites
### Hardware
- ESP32 Microcontroller
- Magnetic Reed Switch Sensors, Push Buttons, OLED Display, Buzzer, LEDs
- **Software:** Arduino IDE with ESP32 Board Manager installed.

### Software & Cloud
- **Framework:** Flutter (Dart)
- **Database:** Firebase Cloud Firestore
- **IDE:** Visual Studio Code / Android Studio
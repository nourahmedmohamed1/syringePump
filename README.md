# 🐘 EleCare: Smart Syringe Pump Controller

<div align="center">
  <h3>Next-generation pediatric infusion monitoring with an interactive, friendly companion.</h3>
</div>

---

## 🌟 Overview

**EleCare** is a modern Flutter application designed to interface with a Smart Syringe Pump via Bluetooth. It provides healthcare professionals with precise control over infusion parameters (dose, flow rate, volume) while simultaneously offering a **state-of-the-art "Kids Mode"** to reduce anxiety and entertain pediatric patients during their treatment.

## ✨ Key Features

### 🩺 Clinical Mode (For Healthcare Professionals)
*   **Bluetooth Connectivity**: Seamless integration with the syringe pump hardware (using `flutter_bluetooth_serial`).
*   **Real-time Monitoring**: Live tracking of the infusion progress, volume delivered, and flow rate.
*   **Parameter Control**: Easy-to-use interface for adjusting critical medical parameters safely.
*   **Demo Mode**: Fully functional simulation mode for training and demonstration without requiring physical hardware.

### 🎈 Kids Mode (For Pediatric Patients)
The app features a dedicated, distraction-therapy interface designed specifically for children, featuring our friendly mascot, **Ellie the Elephant**:

*   **🗣️ Ellie Speaks**: Ellie auto-speaks encouraging messages and guides the child through calming breathing exercises. Fully bilingual (Arabic & English) with text-to-speech (TTS) support.
*   **🎤 Talk to Ellie**: A fun "Talking Tom"-style feature! Kids can tap the microphone and speak to Ellie, and she will listen and repeat what they say in her cute, high-pitched voice.
*   **🎮 Catch the Drops Mini-Game**: An interactive, custom-built game where kids help Ellie catch falling medicine drops (`💧💊🩹`). Features multiple lives, spark particle effects (`✨`), a syringe-bottle fill indicator, and enthusiastic celebration messages.

## 🌐 Bilingual Support
EleCare is built from the ground up to support both **English** and **Arabic**. 
*   UI elements, buttons, and progress indicators switch seamlessly.
*   Text-to-Speech (TTS) automatically switches between `en-US` and Arabic locales.
*   Speech-to-Text (STT) recognition adapts to the selected language.

## 🛠️ Technology Stack
*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Hardware Comms**: `flutter_bluetooth_serial`
*   **Voice/Audio**: 
    *   `flutter_tts` (Text-to-Speech)
    *   `speech_to_text` (Voice Recognition)
*   **UI/UX**: Custom `CustomPainter` animations, `GoogleFonts`, fluid `AnimatedContainer` transitions, and complex gradient styling.

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (v3.0.0 or higher)
*   An Android device for testing (Bluetooth and Microphone features require physical hardware).

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/nourahmedmohamed1/syringePump.git
   ```
2. Navigate to the project directory:
   ```bash
   cd syringePump
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## 📱 Permissions Required
For full functionality on Android, the app requires the following permissions (already configured in `AndroidManifest.xml`):
*   `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` (For hardware communication)
*   `RECORD_AUDIO` (For the "Talk to Ellie" speech recognition feature)

---
<div align="center">
  <i>Built with ❤️ to make healthcare a little less scary for kids.</i>
</div>

# RemGloves

A Flutter mobile app for a smart glove that uses ASL-inspired hand gestures to wirelessly control smart home devices. Flex sensors on an ESP32-powered glove send bend data over BLE; the app translates gestures into relay commands for TVs, lights, and fans — no touch or voice required.

---

## Features

| Screen | Description |
|---|---|
| **Monitor** | Live relay status (TV, Fan, Light) via MQTT with optimistic toggles and rollback |
| **3D Simulation** | Real-time WebGL hand model (Three.js) animated from live BLE flex sensor data; drag to orbit, pinch to zoom |
| **Logs & Analytics** | Firebase gesture history with Today / 7-day / 30-day filtering, stats, paginated log list, and Gemini AI summary |
| **Settings** | BLE calibration, named glove profiles, push WiFi credentials to ESP32, auto-connect toggle |
| **Serial Monitor** | Live BLE debug log stream from the glove |

---

## Tech Stack

- **Flutter** (Android / iOS)
- **BLE** — Nordic UART Service; streams 5-finger bend percentages + gesture codes from ESP32
- **MQTT** — HiveMQ Cloud; publishes relay commands and subscribes to device state
- **Firebase Realtime Database** — stores gesture events (timestamp + command)
- **Gemini 2.5 Flash Lite** — generates natural-language summaries of gesture sessions
- **Three.js** in WebView — 3D hand model with OrbitControls
- **SharedPreferences** — local calibration profile persistence

---

## Architecture

```
MainShell (IndexedStack, 4 tabs)
├── MonitorScreen       ← MQTT relay control
├── SimulationScreen    ← BLE → 3D hand model
├── LogsScreen          ← Firebase + AI analytics
└── SettingsScreen      ← Calibration, profiles, WiFi
    └── SerialMonitorScreen

Shared services (injected top-down):
  BleService     — BLE connect / data stream / calibration
  MqttService    — MQTT connect / publish / subscribe
  GestureLogService — buffers & writes gestures to Firebase
  ProfileService    — saves/loads calibration profiles
  AiSummaryService  — Gemini API calls
```

Calibration data auto-saves on every glove reconnect and can be pushed back to the ESP32 with a single tap.

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11`
- Android device / emulator (API 21+) or iOS device
- RemGloves ESP32 glove hardware
- Firebase project with Realtime Database enabled
- HiveMQ Cloud MQTT broker credentials
- Gemini API key

### Setup

```bash
git clone https://github.com/marjorie033/RemGloves-Software.git
cd RemGloves-Software/remgloves_app
flutter pub get
```

Add your credentials to the appropriate config files (Firebase `google-services.json`, MQTT and Gemini keys in the service files), then run:

```bash
flutter run
```

---

## Gesture Mapping

| Gesture Code | Action |
|---|---|
| Thumb only | TV Power |
| Index only | Light ON/OFF |
| Middle only | Fan ON/OFF |
| Ring + Pinky | TV Channel Up |
| All fingers | TV Volume Up |
| Fist | All OFF |

*Exact mappings are configurable via the calibration flow.*

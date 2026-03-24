# RemGlove Flutter App

A mobile frontend for the RemGlove smart gesture-control glove, built with Flutter/Dart.

## Screens

| Screen | Description |
|--------|-------------|
| **Monitor** | Live device status for Smart Light, Fan, TV with ON/OFF toggles |
| **3D Sim** | Placeholder for Unity real-time 3D hand render + active gesture display |
| **Logs** | Scrollable command history with timestamps |
| **Settings** | User profile, Gesture Guide, Bluetooth/WiFi toggles |

## Project Structure

```
lib/
  main.dart                  # App entry, bottom nav shell
  theme/
    app_theme.dart           # Colors, typography, theme data
  widgets/
    app_bar.dart             # Shared RemGlove top app bar (amber + battery row)
  screens/
    monitor_screen.dart      # Live Device Status
    simulation_screen.dart   # 3D Sim placeholder
    logs_screen.dart         # History log
    settings_screen.dart     # Account + Connectivity settings
```

## Setup

```bash
flutter pub get
flutter run
```

Requires Flutter 3.x or later.

## 3D Model (Coming Soon)

The **3D Simulation** screen currently shows a styled placeholder.  
Prompt the next phase to integrate a Unity WebGL view or a native 3D hand model renderer.

## Design Tokens

| Token | Value |
|-------|-------|
| Primary | `#F5A623` (amber/orange) |
| Background | `#F5F5F5` |
| Toggle ON | `#4CAF50` (green) |
| Text Primary | `#1A1A1A` |
| Text Secondary | `#888888` |
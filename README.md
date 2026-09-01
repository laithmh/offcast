# 📡 Hotspot Screen Cast (Ultra-Low Latency P2P Screen Mirroring)

A high-performance, offline peer-to-peer screen sharing and camera viewfinder application built with **Flutter**, **WebRTC**, and **Light Neumorphism**. Designed for content creators, camera monitoring, and direct phone-to-tablet/phone-to-phone wireless displays with **sub-25ms latency** over a local Wi-Fi Hotspot without requiring any internet connection.

---

## 🌟 Key Features

- ⚡ **Ultra-Low Latency (<25ms)**: Hardware-accelerated H.264 Baseline encoding with zero-delay playout (`a=playout-delay:0 0`).
- 📶 **100% Offline & Direct**: Connects directly over Android Portable Hotspot or local Wi-Fi. Zero cloud servers, zero STUN/TURN, zero internet required.
- 🔄 **Android SoftAP WebRTC Loopback Relay**: Built-in in-process `LocalUdpRelay` solves the Android tethering isolation issue permanently.
- 🎯 **Zero-Touch Auto-Discovery**: Automatic device discovery using UDP subnet beacons (Port 8888) with instant pairing.
- 🪞 **Wireless Selfie Viewfinder**: Real-time horizontal flip mirroring for natural camera framing while recording videos.
- 🎨 **Light Neumorphism UI**: Clean, tactile design system with real-time telemetry HUD (FPS, Latency in ms, Bitrate in Mbps).
- 📱 **Universal Multi-Device Support**: Fully responsive on compact phones, standard smartphones, foldables, tablets, and desktop.

---

## 🏗️ Architecture & How It Works

```
┌────────────────────────────────────────┐          Wi-Fi Hotspot / LAN          ┌────────────────────────────────────────┐
│             SENDER (Phone)             │◄─────────────────────────────────────►│           RECEIVER (Tablet/PC)         │
│  - MediaProjection (720x1600 @ 60 FPS) │                                       │  - Embedded WebSocket Signaling Server │
│  - H.264 Baseline Hardware Encoder     │           UDP Beacon (Port 8888)      │  - UDP Discovery Broadcaster           │
│  - LocalUdpRelay (Bridge 0.0.0.0)      │◄─────────────────────────────────────►│  - LocalUdpRelay (Bridge 0.0.0.0)      │
│  - WebRTC PeerConnection (C++ Engine)  │         RTP/SRTP Direct Video Stream  │  - Hardware Accelerated RTCVideoView   │
└────────────────────────────────────────┘                                       └────────────────────────────────────────┘
```

### 1. The Android SoftAP WebRTC Challenge & Solution
Android considers a Portable Hotspot (`ap0` / `wlan1`) a downstream tethering interface rather than an upstream network. WebRTC's C++ `NetworkMonitor` binds only to `127.0.0.1` in offline tethering mode. 

**Solution:** Our in-process `LocalUdpRelay` dynamically intercepts packets on `0.0.0.0` and bridges them bi-directionally to `127.0.0.1`, keeping the WebRTC engine fully functional offline with zero packet loss.

### 2. Zero-Playout-Delay & Low Thermal Overhead
- **SDP Munging**: Injects `a=playout-delay:0 0` to bypass receiver video jitter buffers.
- **H.264 Baseline Profile**: Restricts encoding to `profile-level-id=42e01f` (0 B-frames), offloading 100% of video compression to dedicated low-power ASIC silicon to keep your phone cool while recording.

---

## 🚀 How to Use

### 1. Connect Devices
1. Turn on **Portable Hotspot** on either device (Phone or Tablet).
2. Connect the other device to this Wi-Fi Hotspot.

### 2. Start Display Monitor (Receiver)
1. Open the app on the display device and tap **Start Receiver**.
2. The screen will start listening and broadcast its presence over UDP port 8888.

### 3. Start Screen Cast (Sender)
1. Open the app on the casting device and tap **Start Sender**.
2. The app will automatically discover the Receiver's IP and verify the connection.
3. Select your quality preset (**Ultra 60FPS**, **Balanced 30FPS**, or **Performance 60FPS**) and tap **Start Screen Mirroring**.

---

## 🛠️ Quality & Thermal Presets

| Preset | Target Resolution | FPS | Target Bitrate | Ideal Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **💎 Ultra** | 720 x 1600 | 60 FPS | 4.5 Mbps | Gaming, fluid high-frame-rate monitoring |
| **⚖️ Balanced** | 720 x 1600 | 30 FPS | 2.5 Mbps | Video recording viewfinder, minimum heat & battery |
| **⚡ Performance** | 540 x 1200 | 60 FPS | 1.8 Mbps | Low-latency on entry-level hardware |

---

## 📦 Project Structure

```
lib/
├── core/
│   ├── constants/webrtc_constants.dart      # WebRTC presets, SDP injections, zero playout delay
│   ├── models/signaling_message.dart        # JSON signaling serialization
│   ├── network/
│   │   ├── discovery_beacon.dart            # UDP broadcast & listener beacon
│   │   └── local_udp_relay.dart             # In-process UDP loopback bridge
│   ├── services/foreground_service_helper.dart
│   ├── theme/app_theme.dart                 # Light Neumorphic theme tokens & dual shadows
│   ├── utils/permission_helper.dart
│   └── widgets/neumorphic_widgets.dart      # Reusable neumorphic primitives
├── features/
│   ├── home/presentation/home_screen.dart   # Universal adaptive mode selector
│   ├── receiver/                            # Display Monitor module
│   │   ├── bloc/
│   │   ├── data/
│   │   └── presentation/receiver_screen.dart
│   └── sender/                              # Screen Caster module
│       ├── bloc/
│       ├── data/
│       └── presentation/sender_screen.dart
└── main.dart
```

---

## 🧪 Testing & Verification

```bash
# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test
```

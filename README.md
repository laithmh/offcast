# 📡 Hotspot Screen Cast (Ultra-Low Latency P2P Screen Mirroring)

A high-performance, offline peer-to-peer screen sharing and camera viewfinder application built with **Flutter**, **WebRTC**, and **Light Neumorphism**. Designed for content creators, camera monitoring, and direct phone-to-tablet/phone-to-phone wireless displays with **sub-25ms latency** over a local Wi-Fi Hotspot without requiring any internet connection.

---

## 🌟 Key Features

- ⚡ **Ultra-Low Latency (<25ms)**: Hardware-accelerated H.264 Baseline encoding with zero-delay playout (`a=playout-delay:0 0`).
- 📷 **Wireless Camera Viewfinder**: Open your phone's native camera app (for 4K HDR recording with stabilization) while monitoring the live viewfinder in real time on your tablet.
- 🪞 **Selfie Mirroring (Horizontal Flip)**: Flip the display feed horizontally for natural, non-inverted self-viewing.
- 🔄 **90° Orientation Rotation**: Instant 90° rotation button on the receiver display.
- 📶 **100% Offline & Direct**: Connects directly over Android Portable Hotspot or local Wi-Fi. Zero cloud servers, zero STUN/TURN, zero internet required.
- 🔄 **Android SoftAP WebRTC Loopback Relay**: Built-in in-process `LocalUdpRelay` solves the Android tethering isolation issue permanently.
- 🎯 **Zero-Touch Auto-Discovery**: Automatic device discovery using UDP subnet beacons (Port 8888) with instant pairing.
- 🎨 **Light Neumorphic Design**: Clean, modern `#E9ECEF` design system with dual soft shadows and real-time telemetry HUD (FPS, Latency, Bitrate).
- 📱 **Universal Multi-Device Support**: Optimized for all Android screen sizes and aspect ratios.

---

## 🚀 How to Use

### 1. Connect Devices
1. Turn on **Portable Hotspot** on either device (Phone or Tablet).
2. Connect the other device to this Wi-Fi Hotspot.

### 2. Start Display Monitor (Receiver)
1. Open the app on the display device and tap **Start Receiver**.
2. Keep the receiver screen open.

### 3. Start Screen Cast (Sender)
1. Open the app on the casting phone and tap **Start Sender**.
2. Tap **Start Screen Mirroring**.
3. Open your phone's **Default Camera App** and tap **Record**! Watch yourself in real time on the tablet.

---

## 🛠️ Performance Presets

| Preset | Target FPS | Target Bitrate | Ideal Use Case |
| :--- | :--- | :--- | :--- |
| **💎 Ultra** | 60 FPS | 5.5 Mbps | High-frame-rate fluid monitoring & gaming |
| **⚖️ Balanced** | 30 FPS | 3.5 Mbps | Video recording viewfinder, minimum heat & battery |
| **⚡ Performance** | 60 FPS | 2.2 Mbps | Low-bandwidth smooth motion for budget devices |

---

## 🧪 Testing & Verification

```bash
# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test
```

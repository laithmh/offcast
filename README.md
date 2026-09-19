<p align="center">
  <img src="asset/app_logo.png" alt="OffCast Logo" width="120" height="120" style="border-radius: 24px;" />
</p>

<h1 align="center">📡 OffCast</h1>

<p align="center">
  <strong>Ultra-Low Latency Offline Director Monitor & Teleprompter for Mobile Video Creators</strong><br>
  <em>Direct Mobile Wi-Fi Hotspot • Zero Internet • Silicon Hardware H.264 • &lt;20ms Glass-to-Glass Latency • Sub-40°C Low Heat</em>
</p>

<p align="center">
  <a href="https://github.com/laithmh/offcast/releases/tag/v1.0.0%2B1">
    <img src="https://img.shields.io/badge/Release-v1.0.0%2B1_APK_Download-brightgreen?style=for-the-badge&logo=android" alt="Download APK" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white" alt="CI/CD" />
  <img src="https://img.shields.io/badge/WebRTC-Hardware_H.264-orange?logo=webrtc" alt="WebRTC" />
  <img src="https://img.shields.io/badge/Latency-%3C20ms-success" alt="Latency" />
  <img src="https://img.shields.io/badge/Framerate-Solid_30_FPS-blue" alt="Framerate" />
  <img src="https://img.shields.io/badge/Security-Pre--Shared_PIN_(PSP)-blue" alt="Security" />
  <img src="https://img.shields.io/badge/Offline-100%25_Direct_Hotspot-green" alt="Offline" />
  <img src="https://img.shields.io/badge/Storage-Persistent_Script_Library-purple" alt="Storage" />
  <img src="https://img.shields.io/badge/Tests-50_Passed_(0_Warnings)-success" alt="Tests" />
  <img src="https://img.shields.io/badge/License-Showcase_%2F_All_Rights_Reserved-purple" alt="License" />
</p>

---

## 📚 Complete Documentation Suite

Explore the deep-dive documentation for engineering breakdowns, creator guides, and career evaluation:

| Document | Focus Area | Description |
| :--- | :--- | :--- |
| 🛠️ [**Technical Architecture**](docs/TECHNICAL_ARCHITECTURE.md) | **Systems Engineering** | WebRTC SDP playout munging, in-process Kotlin UDP relay (`nice=-19`), Shelf signaling, and Audio VAD DSP. |
| 🌟 [**Features Showcase**](docs/FEATURES_SHOWCASE.md) | **Product & Creators** | Viewfinder monitoring, draggable teleprompter, social framing grids (9:16 safe zones), and thermal profiles. |
| 💼 [**Portfolio & CV Kit**](docs/PORTFOLIO_AND_CV.md) | **Recruiters & Leads** | Google XYZ resume bullets, skills matrix, Mermaid system architecture diagram, and technical interview Q&A. |
| 🚀 [**CI/CD & Release Guide**](docs/CICD_AND_RELEASE_GUIDE.md) | **DevOps & Automation** | Dual GitHub Actions pipelines, automated APK releases on Git tags, and keystore secrets setup. |

---

## 📸 App Screenshots

<p align="center">
  <img src="asset/screenshots/01_mode_selection.jpg" width="31%" alt="Mode Selection Screen" />
  &nbsp;
  <img src="asset/screenshots/02_receiver_pairing.jpg" width="31%" alt="Director Monitor & Security PIN" />
  &nbsp;
  <img src="asset/screenshots/03_sender_config.jpg" width="31%" alt="Sender Config & Quality Presets" />
</p>

---

## 📖 Overview

**OffCast** turns any secondary phone or tablet into a professional **wireless director's monitor and teleprompter** for solo mobile video creators. 

Solo creators often struggle when filming themselves: using the high-quality rear camera means you can't see your framing, focus, or expressions, while direct camera-casting apps lock the camera hardware and block the phone's native camera app.

OffCast solves this completely:
1. **Transmit Viewfinder**: Broadcasts your recording phone's screen over a direct, offline local Wi-Fi hotspot with sub-20ms glass-to-glass latency.
2. **Shoot with Native Camera**: Run your phone's stock camera app at full 4K 60 FPS, ProRes, or HDR with zero sensor lockout.
3. **Monitor on Tablet**: Mount a tablet or second phone beside your lens to inspect framing, check posture with rule-of-thirds grids, and read your script from a draggable, transparent teleprompter overlay.
4. **No Thermal Throttling**: Designed specifically to eliminate phone heat (staying under 40°C) with hardware silicon H.264 encoding and 30 FPS pacing.

---

## 🌟 Key Features

### ⚡ Ultra-Low Latency Video Pipeline (&lt;20ms)
- **Hardware-Accelerated Encoding**: Direct hardware encoding using H.264 Baseline Profile via native silicon MediaCodec (Qualcomm & MediaTek).
- **Instant Zero-Delay Playout (`a=playout-delay:0 0`)**: Completely bypasses WebRTC's artificial receiver jitter buffering, rendering incoming frames instantaneously.
- **Framerate Preservation (`MAINTAIN_FRAMERATE`)**: Enforces fluid 30 FPS motion under any thermal or network adaptation rather than dropping to a jerky 10–15 FPS.
- **Continuous Frame Delivery (`minFrameRate: 24`)**: Prevents Android's VirtualDisplay / MediaProjection pipeline from pausing or idling during static framing shots.

### 📜 Teleprompter with Offline Script Library
- **Draggable & Resizable Monitor Overlay**: Freely reposition the prompter anywhere across the live monitor feed.
- **Transparent Floating Text Mode**: Strips the slate background for high-visibility floating text with custom drop-shadows.
- **Persistent Script Library**: Auto-saves your scripts, scroll velocity, and typography locally using `shared_preferences`. Create, name, and switch between multiple scripts (*"Intro & Hook"*, *"Sponsor Read"*, *"Outro"*) with one tap.
- **Speech-Aware Voice Activity Detection (VAD)**: Offline speech recognition on the tablet that automatically scrolls the script as you speak and pauses the moment you pause to breathe.

### 📐 Production Social Framing Guides
- **9:16 Shorts & Reels Safe Zone**: High-contrast overlay to ensure your head and framing stay clear of TikTok/Reels UI buttons and captions.
- **16:9 YouTube / Broadcast Guide**: Standard widescreen composition box.
- **Rule-of-Thirds Grid (3×3)**: Golden composition grid to keep your eyes locked at the upper third horizon.
- **1:1 Square Guide**: For Instagram feeds and square video formats.
- **Zero Phone Overhead**: All framing guides are drawn on the tablet GPU via Flutter CustomPainter, consuming 0% CPU on your camera phone.

### ❄️ Low-Heat Silicon Thermal Optimization
- **Eliminates Overheating**: Caps screen capture to 30 FPS (reducing encoder load by 50% vs 60 FPS), keeping the recording phone cool even during 30+ minute continuous takes.
- **Two Tailored Presets**:
  - **Cool Viewfinder (540p 30 FPS, ~850 Kbps)**: Maximum thermal endurance and battery life for long studio shoots.
  - **HD Viewfinder (720p 30 FPS, ~1800 Kbps)**: Crisp resolution for critical focus and detail inspection.
- **Live Thermal Telemetry**: Real-time HUD displaying transmitter temperature (°C), thermal throttling status, bitrate, FPS, and latency.

### 🔒 Pre-Shared PIN (PSP) Session Security
- **Hotspot Protection**: Protects open hotspot networks from unauthorized stream viewers.
- **Two-Tier Authentication Gate**:
  - **HTTP 401 Upgrade Gate**: Direct query parameter authentication (`?pin=XXXX`) during WebSocket handshake.
  - **In-Band Fallback Handshake**: Challenge-response verification for resilient reconnects.
- **Rate-Limiting**: Exponential lockout on consecutive failed attempts from unauthorized local IPs.

### 🔄 Android SoftAP Hotspot AP-Isolation Bypass
- **Native In-Process UDP Relay (`LocalUdpRelay`)**: Solves Android's tethering packet-filtering issue where connected hotspot clients cannot communicate directly with each other.
- Pipes datagrams through a native OS background thread with a 2MB socket buffer at `nice = -19` priority.

---

## ⚙️ Performance Presets

| Preset | Target FPS | Bitrate | Resolution | Purpose | Thermal Profile |
| :--- | :---: | :---: | :---: | :--- | :---: |
| **❄️ Cool Viewfinder** | 30 FPS | ~850 Kbps | 540p | Long continuous shoots (30+ min), lowest battery drain | **&lt;38°C (Cold)** |
| **🎬 HD Viewfinder** | 30 FPS | ~1800 Kbps | 720p | Critical framing, lighting, and focus inspection | **&lt;41°C (Warm)** |

> [!TIP]
> **5 GHz Hotspot Recommendation**: Set your phone's Portable Hotspot band to **5 GHz** in Android Settings. This drops wireless local ping to **2–5ms** and eliminates 2.4 GHz Bluetooth/Wi-Fi congestion.

---

## 🏗️ Technical Architecture Overview

```text
       CAMERA PHONE (TRANSMITTER)                       DIRECTOR TABLET (RECEIVER)
  ┌─────────────────────────────────┐               ┌─────────────────────────────────┐
  │  Native Camera App (4K 60FPS)   │               │  Director Monitor Viewfinder    │
  │  + Screen Mirror VirtualDisplay │               │  + Draggable Teleprompter HUD   │
  │  + Hardware H.264 Silicon Enc   │               │  + Social Framing Guides (3x3)  │
  └────────────────┬────────────────┘               └────────────────▲────────────────┘
                   │                                                 │
                   ▼                                                 │
         [UDP Subnet Discovery] ═══════════════════════════► [UDP Port 8888 Beacon]
                   │                                                 │
                   ▼                                                 │
         [Shelf WebSocket Auth] ── (PIN: XXXX / HTTP 401) ─► [Signaling Server]
                   │                                                 │
                   ▼                                                 │
         [WebRTC PeerConnection] ◄── ICE Host Candidates (SDP) ──────► PeerConnection
                   │            (a=playout-delay:0 0)                ▲
                   │            (MAINTAIN_FRAMERATE)                 │
                   └──────────► [Native In-Process UDP Relay] ───────┘
                                (Bypasses Hotspot AP Isolation)
```

---

## 🚀 Getting Started & Installation

### 📥 Download & Install
Download the pre-compiled Android release APK directly:
👉 [**Download OffCast v1.0.0+1 APK**](https://github.com/laithmh/offcast/releases/tag/v1.0.0%2B1)

### 1. Connect Devices Over Hotspot
1. Turn on **Personal / Portable Hotspot** on your Tablet or Phone (preferably 5 GHz).
2. Connect the other device to this Wi-Fi network.
   *(No mobile data, cellular reception, or internet connection required!)*

### 2. Start Director Monitor (Receiver / Tablet)
1. Open **OffCast** on your tablet and tap **Director Monitor & Prompter**.
2. The screen displays the connection address (e.g. `ws://192.168.0.104:8080`) and a **4-digit PIN**.
3. Mount the tablet directly under or beside your camera tripod.

### 3. Start Camera Transmitter (Sender / Phone)
1. Open **OffCast** on your camera phone and tap **Camera Viewfinder Transmitter**.
2. Tap the auto-discovered Director Monitor (or enter IP and PIN).
3. Select your quality preset (**Cool Viewfinder** or **HD Viewfinder**) and tap **Start Viewfinder Broadcast**.
4. Switch to your phone's **native Camera app** and start recording in full 4K!

---

## 📂 Project Structure

```text
offcast/
├── android/                   # Native Android Kotlin subsystem
│   └── app/src/main/kotlin/com/laithmh/offcast/
│       ├── MainActivity.kt            # Platform channels & multicast locks
│       ├── MediaProjectionService.kt  # Foreground capture service
│       ├── AudioVadEngine.kt          # Native Voice Activity Detection (PCM-16 RMS)
│       └── NativeUdpRelay.kt          # Low-latency SoftAP socket relay (nice=-19)
├── asset/                     # Branded logo and application assets
│   └── screenshots/           # High-resolution production UI captures
├── docs/                      # Comprehensive technical and portfolio documentation
│   ├── TECHNICAL_ARCHITECTURE.md      # Low-level systems engineering deep dive
│   ├── FEATURES_SHOWCASE.md           # Creator feature walkthrough & problem-solution
│   └── PORTFOLIO_AND_CV.md            # Resume bullets, interview Q&A, & skills matrix
├── lib/
│   ├── core/                  # Design tokens, theme, constants, & models
│   │   ├── constants/         # WebRTC presets (540p30 / 720p30)
│   │   ├── models/            # PrompterConfig & SavedScript models
│   │   ├── services/          # PrompterStorageService (SharedPreferences)
│   │   └── utils/             # SDP candidate sanitizer & playout-delay
│   ├── features/
│   │   ├── home/              # Mode selection & setup instructions
│   │   ├── receiver/          # Director monitor, prompter sheet, & framing
│   │   └── sender/            # Viewfinder transmitter, BLoC, & telemetry
│   └── main.dart              # Application bootstrap & routing
├── test/                      # 50 unit and widget test suites
└── pubspec.yaml               # Dependencies & project metadata
```

---

## 🛠️ Development & Verification

### Prerequisites
- Flutter SDK `^3.13.2` or later
- Android SDK 34+ / NDK
- Java 17

### Build & Test Commands

```bash
# Get dependencies
flutter pub get

# Run static analysis (0 warnings)
flutter analyze

# Run complete test suite (50 tests)
flutter test

# Build release APK
flutter build apk --release
```

Release APK output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 License & Rights

This repository is source-available for **portfolio evaluation and educational demonstration purposes only**. All rights are reserved by the author (Laith MH).

Commercial use, modification for public distribution, re-distribution, and deploying this software or derivative works to public app stores are strictly prohibited without prior written permission. See [LICENSE](LICENSE) for full legal terms.

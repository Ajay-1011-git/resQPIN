# ResQPIN

**Real-time Emergency SOS & Disaster Response Platform**

ResQPIN is a comprehensive emergency response application built with Flutter and Firebase that connects citizens, first responders, and family members through real-time tracking, automated alerts, and India Post's DIGIPIN geospatial encoding system.

---whe

## Features

### Emergency SOS System
- **One-tap SOS alerts** for Police, Fire, Ambulance, and Fisherman emergencies
- **Sub-category classification** (Accident, Heart Attack, Theft, Gas Leak, etc.) with severity levels
- **5-second countdown confirmation** to prevent accidental dispatches
- **Atomic officer assignment** via Firestore transactions — prevents duplicate dispatch

### Silent Panic Mode
- **Hardware-triggered activation** — triple-press volume-down within 1.5 seconds
- Silently dispatches a high-severity police alert without any visible UI
- **Background audio recording** (60 seconds, AAC/M4A) via Android's native MediaRecorder for evidence preservation
- Runtime microphone permission handling

### Real-Time Tracking
- **Bidirectional live tracking** between victim, officer, and family members on Google Maps
- **Officer ETA & distance** calculated via Haversine formula (40 km/h urban average)
- **Status pipeline**: `OPEN` → `ASSIGNED` → `CLOSED` with live status updates
- Officer, victim, and family markers rendered simultaneously

### DIGIPIN Geospatial Encoding
- Converts WGS84 coordinates to India Post's **10-character alphanumeric geocode** (XXX-XXX-XXXX)
- Faithful implementation of IIT Hyderabad + NRSC/ISRO algorithm
- Eliminates coordinate formatting errors during dispatch

### Family Circle
- **Unique 6-character code** system for linking family members
- Send/accept link requests with real-time Firestore synchronization
- **Automatic family alerts** when an SOS is triggered — family members can join tracking sessions
- Independent family responder tracking with live location broadcasting

### Fisherman Mode
- **Real-time marine weather dashboard** — wind speed, gusts, wave height, swell, pressure, sea condition
- **IMD cyclone classification** — automatic tiered storm alerts (Cyclonic Storm through Very Severe Cyclonic Storm)
- **Low pressure**, **high wave**, **thunderstorm**, and **swell advisories** via Open-Meteo API
- Local push notifications for severe weather events
- Auto-refresh every 5 minutes with manual refresh

### Crime Heatmap
- Interactive density heatmap across 100+ Indian cities
- Color-coded 6-tier legend from low to high crime density
- Data source: MOSPI Statistical Abstract India (IPC crimes)

### Officer Dashboard
- Department-filtered alert feed (Police / Fire / Ambulance / Coast Guard)
- Live location broadcasting to Firestore while on duty
- One-tap alert attendance with atomic conflict prevention

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart SDK ^3.11.0) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore (real-time streams) |
| Push Notifications | Firebase Cloud Messaging + Flutter Local Notifications |
| Maps | Google Maps Flutter SDK |
| Location | Geolocator (5m distance filter) |
| Weather | Open-Meteo API (no API key required) |
| Native Audio | Android MediaRecorder via MethodChannel (Kotlin) |
| Geocoding | DIGIPIN (India Post) |
| UI | Glassmorphism design system with Google Fonts |

---

## Project Structure

```
lib/
├── main.dart                     # App entry, Firebase init, auth routing
├── app_theme.dart                # Dark glassmorphism theme, glass containers
├── constants.dart                # SOS types, departments, categories, colors
├── firebase_options.dart         # Firebase configuration (gitignored)
├── models/
│   ├── user_model.dart           # User profile (PUBLIC / OFFICER roles)
│   ├── sos_model.dart            # SOS alert with status lifecycle
│   ├── family_link_model.dart    # Family linking (linked + pending)
│   └── officer_location_model.dart
├── screens/
│   ├── login_screen.dart         # Animated glassmorphic login
│   ├── signup_screen.dart        # Registration with role selection
│   ├── public_dashboard.dart     # Citizen hub — SOS buttons, family alerts
│   ├── officer_dashboard.dart    # Officer hub — filtered alert feed
│   ├── sos_category_screen.dart  # Sub-category & severity picker
│   ├── sos_confirmation_dialog.dart  # 5-second countdown
│   ├── sos_tracking_screen.dart  # Live multi-marker tracking map
│   ├── alert_detail_screen.dart  # Officer alert view + attendance
│   ├── family_screen.dart        # Family Circle management
│   ├── family_tracking_screen.dart   # Family responder tracking
│   ├── fisherman_mode_screen.dart    # Marine weather + SOS
│   └── heatmap_screen.dart       # Crime density visualization
├── services/
│   ├── auth_service.dart         # Firebase Auth wrapper
│   ├── firestore_service.dart    # Firestore CRUD + streams
│   ├── sos_service.dart          # SOS creation orchestrator
│   ├── location_service.dart     # Geolocator + Haversine + ETA
│   ├── weather_service.dart      # Open-Meteo + IMD cyclone classification
│   ├── notification_service.dart # Local + push notifications
│   ├── panic_service.dart        # Native panic channel (volume-down)
│   └── digipin_service.dart      # DIGIPIN encoder/decoder
├── utils/
│   └── animations.dart           # Shared animation controllers
└── widgets/
    ├── emergency_button.dart     # Glassmorphic SOS button with glow
    └── glass_widgets.dart        # Reusable glass UI components
```

---

## Getting Started

### Prerequisites

- Flutter SDK (v3.19.0+)
- Android Studio / VS Code
- Firebase project with Authentication and Firestore enabled
- Google Maps API Key

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ajay-1011-git/resQPIN.git
   cd resQPIN
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration:**
   - Create a Firebase project and add an Android app with package name `com.example.resqpin`
   - Download `google-services.json` → place in `android/app/`
   - Generate `firebase_options.dart` using FlutterFire CLI → place in `lib/`

4. **Google Maps API Key:**
   Add your key to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE"/>
   ```

5. **Run:**
   ```bash
   flutter run
   ```

---

## User Roles

| Role | Access | Sign-up Requirement |
|------|--------|-------------------|
| **Public** | SOS alerts, Family Circle, Fisherman Mode, Heatmap | Any email |
| **Officer** | Alert dashboard, attendance, live tracking | Official `.gov.in` email domain |

Officer email domains: `police.gov.in`, `health.gov.in`, `fireservice.gov.in`, `coastguard.gov.in`

---

## Firestore Collections

| Collection | Purpose |
|-----------|---------|
| `users` | User profiles with role, department, unique code |
| `sos` | SOS alerts with full lifecycle (OPEN → ASSIGNED → CLOSED) |
| `sos/{id}/family_responders/{uid}` | Family member tracking data per alert |
| `family_links` | Family linking graph (linked users + pending requests) |
| `officer_locations` | Real-time officer GPS coordinates |

---

## Contributing

Contributions, issues, and feature requests are welcome.

## License

This project is licensed under the MIT License.

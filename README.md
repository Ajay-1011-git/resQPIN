# ResQPIN

**Real-time Emergency SOS & Disaster Response Platform Powered by DIGIPIN**

ResQPIN is a next-generation emergency response application that bridges the critical communication gap between citizens, first responders, and families. Built with Flutter and Firebase, it introduces a novel approach to emergency geolocation by integrating **India Post's DIGIPIN** system to ensure millimeter-perfect, error-free location sharing when every second counts.

---

## The Problem

During critical emergencies, locating the victim is often the greatest challenge for first responders. Traditional location sharing relies on complex GPS coordinates (Latitude/Longitude) or vague addresses, which are prone to:
- **Communication Errors:** Reading out or typing a 15-digit coordinate over a frantic phone call often leads to critical typos.
- **Ambiguity in Remote Areas:** Rural areas, highways, or open waters (for fishermen) lack standard street addresses.
- **Dispatch Delays:** Precious minutes are wasted trying to format, transmit, and verify exact pinpoint locations, delaying arrival times drastically.

##  The Solution & Our Unique Selling Point (USP): DIGIPIN

**ResQPIN eliminates location ambiguity by natively integrating India Post's DIGIPIN geospatial encoding system.** 

Instead of dealing with complex coordinates, the app instantly converts precise WGS84 GPS data into a simple, 10-character alphanumeric geocode (e.g., `G8M-3X4-L9Q2`). 

**Why DIGIPIN is a game-changer for emergency response:**
- **Human-Readable & Error-Free:** A short 10-character string is infinitely easier to communicate over radio, phone, or text than raw lat/long coordinates.
- **Universal Accuracy:** Based on the IIT Hyderabad + NRSC/ISRO algorithm, it divides the entire country into a highly precise 4m x 4m grid.
- **Zero Ambiguity:** Whether you are in a dense urban slum, halfway down a highway, or lost at sea, your DIGIPIN is an absolute, immutable location identifier.
- **Seamless Dispatch:** First responders can instantly decode the DIGIPIN directly within their dashboard to route directly to the victim without secondary clarification.

---

##  Key Features

### Emergency SOS System
- **One-Tap Alerts:** Instant dispatch for Police, Fire, Ambulance, and Coast Guard emergencies.
- **Smart Classification:** Categorization by emergency type (Accident, Fire, Theft, etc.) determining optimal response priorities (Severity: HIGH/MED/LOW).
- **Atomic Dispatch:** Built on Firestore transactions to assign exactly *one* officer per incident, preventing duplicate dispatching conflicts.

### Silent Panic Mode
- **Hardware-Triggered:** Activate silently by triple-pressing the volume-down button within 1.5 seconds.
- **Covert Operation:** Dispatches a high-severity police alert without waking the screen or showing UI.
- **Evidence Preservation:** Automatically invokes native Android background audio recording (AAC/M4A) for 60 seconds.

### Bi-Directional Live Tracking
- **Live Map Synchronization:** Victim, assigned officer, and family responders are all tracked live on an interactive Google Map.
- **ETA & Distance Calculation:** Real-time distance and ETA via the Haversine formula (optimized for urban averages).
- **Status Pipeline:** Transparent alert lifecycle (`OPEN` → `ASSIGNED` → `CLOSED`).

### Family Circle Integration
- **Unique Linking:** Connect family members using a secure 6-character unique code system.
- **Broadcast Alerts:** If a user triggers an SOS, all linked family members are instantly notified and can join the tracking session live.

### Fisherman Mode (Marine Safety)
- **Marine Weather Dashboard:** Real-time monitoring of wind speed, wave height, swell, and sea pressure via Open-Meteo API.
- **Cyclone & Storm Advisories:** Automatic tiered alerts leveraging IMD classifications (Cyclonic Storm through Very Severe).
- **Geo-fenced SOS:** Coast Guard specific dispatching tailored for marine environments.

### Crime Heatmap
- **Data-Driven Insight:** Interactive density heatmap covering 100+ Indian cities.
- **Actionable Intelligence:** Visualizes crime density utilizing MOSPI Statistical Abstract data, helping citizens avoid high-risk areas.

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter (Dart SDK ^3.11.0) |
| **Authentication** | Firebase Auth |
| **Database** | Cloud Firestore (Real-time streams) |
| **Location / Maps** | Geolocator & Google Maps Flutter SDK |
| **Geocoding API** | Native DIGIPIN implementation (India Post algorithm) |
| ** (Serverless/No Auth) |
| **Native Integration**| Android MethodChannels (Kotlin) for Panic Mode & Audio |
| **UI/UX System** | Custom Glassmorphism design with Google Fonts (Inter) |

---

## Getting Started

### Prerequisites
- Flutter SDK (v3.19.0+)
- Android Studio / VS Code
- Firebase Project (Auth & Firestore enabled)
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
   - Create a Firebase project. Add an Android app with the package name `com.example.resqpin`.
   - Download the generated `google-services.json` and place it in the `android/app/` directory.
   - Run the FlutterFire CLI to generate `firebase_options.dart` in the `lib/` directory.

4. **Google Maps API Key:**
   Add your API key to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE"/>
   ```

5. **Run the App:**
   ```bash
   flutter run
   ```

---

## User Roles & Access

| Role | Capabilities | Registration Requirement |
|------|-------------|--------------------------|
| **Public User** | Trigger SOS, Family Circle, Fisherman Mode, View Heatmap | Standard Email |
| **First Responder** | Access Officer Dashboard, Accept Alerts, Live Tracking | Official Govt Domain (`.gov.in`) |

*Authorized Responder Domains:* `police.gov.in`, `health.gov.in`, `fireservice.gov.in`, `coastguard.gov.in`

---


## License

This project is licensed under the MIT License.

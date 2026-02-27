# ResQPIN

**ResQPIN** is a critical emergency response and tracking platform engineered with Flutter and Firebase. It bridges the gap between citizens, first responders, and emergency contacts by leveraging real-time telemetry, advanced location encoding, and automated alert systems to facilitate rapid intervention during crises.

## Project Overview

Traditional emergency response systems often suffer from inaccurate location data, delayed dispatch times, and a lack of real-time situational awareness for both the victim and the responding personnel. ResQPIN addresses these systemic inefficiencies by implementing IndiaPost's DIGIPIN standard for high-fidelity geospatial encoding and pairing it with a robust, real-time tracking architecture. 

The application serves multiple distinct user personas—citizens in distress, dispatch officers, specialized maritime users (fishermen), and family members—providing each with a tailored interface and specialized tooling to effectively coordinate emergency responses.

## Technical Architecture & Implementation

### Core Technologies
*   **Application Framework:** Flutter (Dart) for high-performance, cross-platform UI rendering.
*   **Backend Infrastructure:** Firebase Authentication for secure user management and Cloud Firestore for low-latency, real-time data synchronization.
*   **Geospatial Processing:** Google Maps Flutter SDK integrated with Geolocator for live coordinate tracking, distance calculation, and ETA approximation.
*   **Native Integrations:** Custom Kotlin implementation using Android's MediaRecorder and MethodChannel for background audio recording.
*   **External APIs:** Open-Meteo API for real-time marine and atmospheric data.

### System Components

#### 1. Real-Time Telemetry and Tracking
Bidirectional Firestore streams link citizens, family members, and responding officers. The system renders live coordinates on a custom Google Maps interface, dynamically calculating responder ETAs via the Haversine formula while enforcing strict single-alert limits to prevent data collisions.

#### 2. Hardware-Level Panic Activation
A custom Android sub-layer monitors for a volume-down triple-press within a 1.5-second window. Upon detection, it silently dispatches a high-severity police alert and initiates a 60-second background audio recording via Android's native MediaRecorder to secure perishable evidence.

#### 3. DIGIPIN Geospatial Encoding
Integrates IndiaPost's DIGIPIN algorithmic framework to convert standard WGS84 coordinates into an unambiguous 10-character alphanumeric grid reference, eliminating coordinate formatting errors during dispatch.

#### 4. Specialized Marine Safety Dashboard
Interfaces with the Open-Meteo API to parse granular meteorological data (wave heights, swells, wind gusts). The system cross-references this data against the Indian Meteorological Department (IMD) cyclone classification matrix to issue automatic, tiered warnings.

#### 5. Crime Heatmap Visualization
Processes historical crime statistics from the Ministry of Statistics and Programme Implementation (MOSPI) to render an interactive density heatmap, visually delineating high-risk zones across major metropolitan centers.

#### 6. Concurrent Multi-Responder Alerting
Upon SOS activation, a compound query dispatches max-priority alerts to assigned officers and all cryptographically linked family members simultaneously. Family members can securely join the tracking session to coordinate independent responses.

## Real-World Impact

ResQPIN is designed directly mitigate the friction points that cause fatal delays in emergency response:

1.  **Reduced Dispatch Latency:** By automatically routing high-fidelity, encoded location data directly to the officer's device, the system bypasses the traditional, time-consuming call center triaging process.
2.  **Enhanced Responder Safety:** Providing officers with live victim tracking and context allows for better tactical preparation prior to arriving at the scene.
3.  **Proactive Disaster Mitigation:** The maritime alert system transitions emergency management from reactive to proactive. By pushing data-driven severe weather warnings directly to vessels, it prevents maritime emergencies before they occur.
4.  **Decentralized Support Networks:** The family link infrastructure empowers a victim's immediate support network to act concurrently with official responders, drastically increasing the probability of a successful intervention without interfering with the official police state.
5.  **Evidence Preservation:** The automated, hardware-triggered audio recording secures perishable auditory evidence in scenarios where exposing the device is dangerous or impossible.

## Getting Started

### Prerequisites

*   Flutter SDK (v3.19.0 or higher recommended)
*   Android Studio / VS Code
*   A Firebase project with Authentication and Firestore enabled
*   A Google Maps API Key

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Ajay-1011-git/resQPIN.git
    cd resQPIN
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    *   Create a Firebase project and add an Android app with the package name `com.example.resqpin`.
    *   Download `google-services.json` and place it in the `android/app/` directory.
    *   Generate `firebase_options.dart` using the FlutterFire CLI and place it in `lib/`.

4.  **Google Maps Configuration:**
    *   Obtain a Google Maps API Key from the Google Cloud Console.
    *   Add your API key to `android/app/src/main/AndroidManifest.xml`:
        ```xml
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
        ```

5.  **Run the application:**
    ```bash
    flutter run
    ```

## Contributing

Contributions, issues, and feature requests are welcome.

## License

This project is licensed under the MIT License.

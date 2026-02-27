# ResQPIN

**ResQPIN** is a comprehensive emergency response and tracking application built with Flutter and Firebase. It leverages IndiaPost's official **DIGIPIN** grid system to provide high-precision location encoding for rapid SOS response, marine safety, and crime mapping.

## 🌟 Key Features

*   **Public & Officer Modes:** Dedicated interfaces for citizens to report emergencies and for officers to manage and respond to active alerts.
*   **IndiaPost DIGIPIN Integration:** Converts standard latitude/longitude coordinates into the official 10-character alphanumeric DIGIPIN format for precise, standardized location sharing.
*   **Live SOS Tracking:** Real-time Google Maps integration showing the location of the emergency, the responding officer's live location, and calculated ETA.
*   **Fisherman Safety Mode:** A specialized dashboard providing real-time marine weather data (wave height, swell, wind gusts) via the Open-Meteo API, complete with an IMD-classified Storm/Cyclone alert system.
*   **Crime Heatmap:** Interactive visualization of historical crime data (based on MOSPI statistics) distributed across major cities in India to highlight high-risk zones.
*   **Family Link:** Secure linking mechanism allowing family members to monitor the safety status and location of their loved ones during emergencies.
*   **Robust Notification System:** Multi-channel Android alerts (Max Priority SOS, Weather Warnings, Family Alerts) ensuring critical updates are never missed.

## 🛠️ Technology Stack

*   **Frontend:** Flutter (Dart)
*   **Backend:** Firebase (Authentication, Cloud Firestore)
*   **Maps & Location:** Google Maps Flutter, Geolocator
*   **APIs:** Open-Meteo API (Weather/Marine data), Custom DIGIPIN encoding logic
*   **Local Services:** Flutter Local Notifications

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (v3.19.0 or higher recommended)
*   Android Studio / VS Code
*   A Firebase project with Authentication and Firestore enabled.
*   A Google Maps API Key.

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
    *   Set up Firestore Database Security Rules (see `Firestore Rules` section below).

4.  **Google Maps Configuration:**
    *   Obtain a Google Maps API Key from the Google Cloud Console.
    *   Add your API key to `android/app/src/main/AndroidManifest.xml`:
        ```xml
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
        ```

5.  **Run the app:**
    ```bash
    flutter run
    ```

### Firestore Security Rules

Ensure your Firestore rules are configured to allow appropriate access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Officers can read profiles
    }
    match /sos/{sosId} {
      allow create, read, update: if request.auth != null;
    }
    match /officer_locations/{officerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == officerId;
    }
    match /family_links/{linkId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📄 License

This project is licensed under the MIT License.

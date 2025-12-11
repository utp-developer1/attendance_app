# Attendance App (Flutter) - Minimal scaffold

This repository contains a minimal Flutter scaffold for an attendance system that:

- Allows multiple clock-ins and clock-outs.
- Detects user location using GPS and computes whether the user is inside a configured compound (by center lat/lon + radius).
- When outside the compound prompts user to select `Work From Home`, `Alternate Location`, or `Out of Office` as the location type.
- Stores attendance records locally using `shared_preferences`.

Quick start
1. Install Flutter and set up Android/iOS toolchains.
2. Open the folder in your IDE/VS Code or terminal.

Run (from project root):

flutter pub get
flutter run

Android permissions
Add these to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

iOS permissions
Add these to `ios/Runner/Info.plist`:

<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to verify attendance location</string>

Configuration
- Edit `lib/services/location_service.dart` and change `compoundLatitude`, `compoundLongitude`, and `compoundRadiusMeters` to match your company's compound.

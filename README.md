# Real-Time Location Tracker

A Flutter Android app that shows the user's current location on Google Maps, refreshes it every 10 seconds while the app is in the foreground, and draws a line between location updates.

## Features

- Opens a Google Map and animates the camera to the current location.
- Requests location permission and handles GPS being turned off.
- Refreshes the location every 10 seconds while the app is open.
- Moves the current-location marker and shows the latest latitude/longitude in its info window.
- Adds each location update to a blue route polyline. The most recent 1,000 points are retained.
- Includes a recenter control and a manual refresh action.
- Pauses the timer in the background and checks the location again when the app returns to the foreground.

## Before running

1. Install a Flutter SDK that supports Dart 3.13 or newer.
2. Open the project in Android Studio or VS Code.
3. In [Google Cloud Console](https://console.cloud.google.com/), select or create a project, enable **Maps SDK for Android**, set up billing, and create an API key. Restrict the key to **Maps SDK for Android** and the Android app ID `com.example.google_map_assignment`. For the Android app restriction, also add the SHA-1 signing certificate fingerprint. From the `android` directory, run `./gradlew signingReport` on macOS/Linux or `gradlew.bat signingReport` on Windows to find it.
4. Open `android/local.properties` and replace `YOUR_GOOGLE_MAPS_API_KEY` with your key:

   ```properties
   MAPS_API_KEY=your_real_api_key_here
   ```

   Keep the existing `sdk.dir` and `flutter.sdk` entries in that file. Do not commit or publicly share the real API key.
5. From the project root, run:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```
6. Test on a physical Android device with Location enabled, or set a location in the Android Emulator controls.

## Notes

- Google Maps will not display map tiles until a valid API key has been added and Maps SDK for Android is enabled for that key.
- Location refreshes every 10 seconds while this screen is active; background location tracking is not included.
- The line represents sampled locations, not a road-following route. A Directions API integration would be needed to draw routes along roads.

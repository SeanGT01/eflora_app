# SETUP INSTRUCTIONS
## Add internet permission to AndroidManifest.xml

In android/app/src/main/AndroidManifest.xml, add this inside <manifest>:
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

## For iOS, add to ios/Runner/Info.plist:
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>

## Network URLs
- Android emulator: use http://10.0.2.2:5000
- iOS Simulator: use http://localhost:5000
- Real device (same WiFi): use http://192.168.x.x:5000
  Find your IP: run `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
  
## Change URL in: lib/services/api_service.dart
  static const String _base = 'http://10.0.2.2:5000';

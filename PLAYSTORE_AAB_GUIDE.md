# Play Store AAB Release Guide

## 1) Create upload keystore (one time)

Run from project root:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2) Configure Android signing

1. Copy `android/key.properties.example` to `android/key.properties`
2. Update values:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=../upload-keystore.jks
```

Keep `android/key.properties` and `upload-keystore.jks` private.

## 3) Build release app bundle (.aab)

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Output path:

`build/app/outputs/bundle/release/app-release.aab`

## 4) Before uploading to Play Console

- Use a unique package id (replace default `com.example.eflowers`)
- Increase `version` in `pubspec.yaml` for every new release
- Test on a physical Android device in release mode
- Ensure app icon, app name, and privacy policy are final

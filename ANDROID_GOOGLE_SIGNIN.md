# Google Sign-In on Real Android Device

You're developing for **Android only** and using **iOS simulator** for general dev (to avoid emulator heating). Test **Google Sign-In** on a **real Android device** via USB.

## 1. Google Cloud – Android OAuth client

- **Application type:** Android  
- **Package name:** `com.example.majorproject_app` (must match `android/app/build.gradle.kts`)  
- **SHA-1:** Add your **debug** keystore SHA-1.

Get SHA-1:

```bash
cd android && ./gradlew signingReport
```

Use the `SHA1` value under `Variant: debug`. Add it to the Android OAuth client in [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.

**Your debug SHA-1** (add this to your Android OAuth client if not already):

```
02:FD:5C:1B:8B:B4:78:3C:97:9F:6B:F4:88:7C:2E:3F:77:4A:08:71
```

## 2. Backend URL when using real device

The phone cannot use `127.0.0.1`. Use your Mac's **LAN IP** (e.g. `192.168.1.x`).

1. Find IP: **System Settings → Wi‑Fi → Details** (or `ifconfig | grep "inet "`).
2. In `lib/config/app_config.dart`, set:
   ```dart
   static const String backendBaseUrl = 'http://192.168.x.x:8000';  // your LAN IP
   ```
3. Ensure Django runs on `0.0.0.0:8000` and phone + Mac are on the **same Wi‑Fi**.

## 3. Run on device

```bash
flutter run
```

Connect the device via USB, enable USB debugging, and select the device when prompted.

---

**iOS simulator:** Google Sign-In will show "Custom scheme URIs not allowed for WEB client type" because the app uses the Web client there. Use a **real Android device** to test sign-in until you add an iOS OAuth client.

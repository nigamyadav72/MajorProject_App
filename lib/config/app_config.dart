/// Shared app configuration (Django backend, Google OAuth).
/// Use the same base URL as your web app backend.
class AppConfig {
  AppConfig._();

  /// Django backend base URL (no trailing slash).
  /// - iOS sim / same machine: `http://127.0.0.1:8000`
  /// - Android emulator: `http://10.0.2.2:8000`
  /// - Real Android device (USB): `http://<your Mac LAN IP>:8000` (see ANDROID_GOOGLE_SIGNIN.md)
  // static const String backendBaseUrl = 'http://192.168.10.91:8000';
  // static const String modelServerUrl = 'http://192.168.10.91:8001';
  static const String backendBaseUrl = 'http://localhost:8000';
  static const String modelServerUrl = 'http://localhost:8001';

  /// Google OAuth **Web** Client ID — must match Django SocialApp (Google).
  /// Used as serverClientId for backend verification (Android & iOS).
  /// Android uses its own OAuth client (package + SHA-1); iOS needs a separate
  /// iOS client if you test sign-in on iOS sim (see ANDROID_GOOGLE_SIGNIN.md).
  static const String googleWebClientId =
      '379736466398-bskn351unl206g2fmseqbf3odmnaej68.apps.googleusercontent.com';
}

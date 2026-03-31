# E-Pasal App (Flutter Mobile) 📱

E-Pasal App is the native Android and iOS client for the E-Pasal AI-powered e-commerce ecosystem. It combines traditional e-commerce features with an advanced visual search capability, enabling users to find products simply by snapping a photo directly from their mobile camera.

## ✨ Key Features
- **Visual Product Search**: Seamlessly upload or snap a photo of a product to find visually similar items using our AI backend. Includes an integrated image cropper to refine your search.
- **Unified Shopping Experience**: User-centric mobile UI for easy catalog browsing, cart management, and seamless checkouts.
- **Secure Authentication**: Built-in JWT authentication combined with a "one-tap" Google OAuth login for native mobile applications.
- **Native Khalti Payment**: Real-time integration with Khalti digital wallet SDK for effortless and secure local payments (Nepal).
- **Responsive Dark/Light Profiles**: Native OS theme detection ensuring the application looks stunning regardless of user preference.
- **Responsive Animations & State Management**: Smooth page transitions and fluid state handling utilizing modern Flutter architecture.

## 🛠️ Technology Stack
- **Framework**: Flutter (Dart)
- **State Management / Networking**: Standard Provider/Riverpod + http/Dio
- **Payment Processing**: Khalti Native SDK
- **Machine Learning Integration**: Communicates securely with the FastAPI/Hugging Face custom ViT endpoint for picture inference.
- **Authentication**: `google_sign_in` Native Library

## 🚀 Getting Started

### 1. Prerequisites
- Flutter SDK (latest stable release recommended)
- Android Studio or Xcode for deploying to emulators/devices

### 2. Environment Setup
1. Clone the repository and navigate into this directory.
2. Ensure you have the `.env` configuration file properly set up at the root of the flutter directory (if employed). At minimum, you need pointers to your backend API.
   - Example configuration settings in code point to `https://majorproject-deployment-2hsxl.ondigitalocean.app/api`.

### 3. Running the App
```bash
# Get all flutter dependencies
flutter pub get

# Connect an emulator or physical device, then run:
flutter run
```

## 📖 How to Use
1. **Explore Catalog**: Scroll through categories like Electronics, Fashion, and Home Decor natively.
2. **Visual AI Search**: Tap the camera icon in the search bar. Use your device's camera to capture a product, crop it, and submit it. The backend will return matching SKUs.
3. **Payments**: Add to your cart and hit checkout. The Khalti SDK will handle the native popup for credentials. Log in, process, and you will be returned seamlessly to the app's success view.

## 📄 License
This mobile client is licensed under the [MIT License](./LICENSE).

---
**Developed with ❤️ by Nigam Yadav**

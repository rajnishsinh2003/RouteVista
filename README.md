# 🗺️ RouteVista

**RouteVista** is an Intelligent Route-Based Tourism Discovery & Travel Assistance Platform designed to redefine the way you explore the world. Powered by Flutter and enhanced with Gemini AI, RouteVista provides a seamless, personalized, and interactive travel experience.

---

## 🚀 Features

### 🗺️ Intelligent Route Discovery
- **Interactive Maps**: Real-time route planning and exploration using `flutter_map`.
- **Offline Support**: Access your saved routes even without an internet connection.
- **Trending Places**: Stay updated with the most popular destinations worldwide.

### 🤖 AI-Powered Assistance
- **Personalized Travel Bot**: Get instant travel advice, itinerary suggestions, and local tips from our integrated **Gemini AI Chatbot**.
- **Context-Aware Recommendations**: Intelligent suggestions based on your preferences and location.

### 🏨 Travel Management
- **Accommodations**: Browse and discover hotels tailored to your budget and style.
- **Transport Options**: Integrated flight and train search for end-to-end trip planning.
- **Budget Tracking**: Manage your travel expenses effortlessly with our built-in budget manager.

### 🌦️ Real-time Updates
- **Live Weather**: Get accurate weather forecasts for your destination to plan ahead.
- **Monthly Tours**: Curated travel packages and seasonal tour recommendations.

### 👤 User Personalization
- **Profile Management**: Secure authentication with Firebase (Email/Password & Google Sign-In).
- **Favorites & History**: Save your dream destinations and revisit your past trip memories.
- **Social Sharing**: Share your routes and favorite spots with friends and family.

---

## 📸 Screenshots

<!-- ADD SCREENSHOTS HERE -->
<!-- Replace the placeholders below with your actual screenshot URLs or local paths -->

| Onboarding | Home Screen | Map Exploration |
| :---: | :---: | :---: |
| ![Onboarding](https://via.placeholder.com/200x400?text=Onboarding+Screen) | ![Home](https://via.placeholder.com/200x400?text=Home+Screen) | ![Map](https://via.placeholder.com/200x400?text=Map+Screen) |

| AI Chatbot | Profile | Weather |
| :---: | :---: | :---: |
| ![Chatbot](https://via.placeholder.com/200x400?text=AI+Chatbot) | ![Profile](https://via.placeholder.com/200x400?text=Profile+Screen) | ![Weather](https://via.placeholder.com/200x400?text=Weather+Updates) |

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.10.4)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage)
- **AI Engine**: [Google Generative AI (Gemini)](https://ai.google.dev/)
- **Mapping**: [Flutter Map](https://pub.dev/packages/flutter_map) & OpenStreetMap
- **State Management**: Provider / ValueNotifier
- **Animations**: Flutter Animate
- **Storage**: Shared Preferences & Local Cache

---

## ⚙️ Installation & Setup

### Prerequisites
- Flutter SDK installed.
- Firebase project setup.
- Google Gemini API Key.

### Steps
1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/RouteVista.git
   cd RouteVista
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Run `flutterfire configure` if using the FlutterFire CLI.

4. **API Keys**:
   - Add your Gemini API key in the `lib/services/chatbot_service.dart` (or your designated service file).

5. **Run the app**:
   ```bash
   flutter run
   ```

---

## 🤝 Contribution
Contributions are welcome! Feel free to open issues or submit pull requests to make RouteVista even better.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ for Travelers
</p>

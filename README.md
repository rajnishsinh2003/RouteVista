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
OnBoarding
<img width="450" height="1000" alt="Onboarding-1" src="https://github.com/user-attachments/assets/3b4a66bc-45ec-4ace-8e31-97fd9d0a92dc" />
<img width="978" height="2100" alt="Onboarding" src="https://github.com/user-attachments/assets/ef25a4b2-8973-4465-8021-c55adafb57a7" />
Home
<img width="978" height="2100" alt="Home" src="https://github.com/user-attachments/assets/b491c26c-a7e5-446d-a285-b8a4a60e3e2f" />
Quick Services
<img width="978" height="2100" alt="Quick-Services" src="https://github.com/user-attachments/assets/8cab2a5d-9074-48c3-a6b8-5b9ea62760fc" />
RouteVista-AI
<img width="978" height="2100" alt="RouteVista-AI" src="https://github.com/user-attachments/assets/7a36f3b0-501d-48e9-8388-57b307fd9981" />
Saved 
<img width="978" height="2100" alt="Saved-Screen" src="https://github.com/user-attachments/assets/13969ab0-3e60-4a4d-9fc6-8da09872cd04" />
Weather
<img width="978" height="2100" alt="Weather" src="https://github.com/user-attachments/assets/d8bb22f2-63d9-464a-b7bc-07845eaa1b95" />
Monthly Planner
<img width="978" height="2100" alt="Monthly-Tour-Planner" src="https://github.com/user-attachments/assets/874b0ac2-6ef8-4b6c-bf04-71c6f06efddd" />
Profile
<img width="978" height="2100" alt="Profile" src="https://github.com/user-attachments/assets/53ccae4a-dcdd-4cf5-92ca-651c82676f9c" />


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
   git clone https://github.com/rajnishsinh2003/RouteVista.git
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
---

  Made with ❤️ for Travelers

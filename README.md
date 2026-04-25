# Pocket Closet

Digital wardrobe app built with Flutter + SQLite + Firebase.

| Table            | Type     | Description                     |
| ---------------- | -------- | ------------------------------- |
| `categories`     | Master   | 6 clothing categories           |
| `clothing_items` | Main     | Clothes with FK → categories    |
| `outfits`        | Main     | Saved outfit combinations       |
| `outfit_items`   | Junction | Many-to-many: outfit ↔ clothing |

## Setup

### Prerequisites

- Flutter SDK ≥ 3.x
- Firebase project

### 1. Clone & install

```bash
git clone https://github.com/RinaliDaffa/Pocket-Closet.git
cd Pocket-Closet
flutter pub get
```

### 2. Setup Firebase

Firebase config files are **not included** in this repo for security.

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a project or use an existing one
3. Add an Android app with package name `com.example.pocket_closet`
4. Download `google-services.json` → place at `android/app/google-services.json`
5. Run `flutterfire configure` to generate `lib/firebase_options.dart`

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 3. Enable Firebase services

In Firebase Console:

- **Authentication** → Enable Email/Password
- **Firestore** → Create database in production mode
- Deploy security rules:

```bash
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

### 4. Run

```bash
flutter run
```

## Demo

https://youtu.be/boziwn4a33M

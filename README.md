# TripIn

A SwiftUI travel planner that recommends attractions from weather forecasts,
builds full-day itineraries, and offers AI-powered travel tips.

## Stack
- Swift + SwiftUI, MVVM
- Firebase Auth + Firestore
- MapKit
- OpenWeatherMap (weather), Google Places (attractions)
- DeepSeek (`deepseek-chat`) agent with tool calling
- CoreML tabular classifier for category recommendation

## Setup
1. Open the project in Xcode (create the `.xcodeproj` / SwiftUI App target).
2. Add Swift Package dependency: `firebase-ios-sdk`
   (FirebaseAuth, FirebaseFirestore, FirebaseCore).
3. Add your `GoogleService-Info.plist` (from the Firebase console) to the target.
4. Fill in `TripIn/Config/APIKeys.plist` with real keys. **Not committed.**
5. Drop `TravelRecommender.mlmodel` into `TripIn/Resources/`.

## Folder structure
```
TripIn/
├── App/            App entry + root tab bar
├── Core/
│   ├── Agent/      DeepSeek agent loop + tool defs
│   ├── ML/         CoreML wrapper
│   ├── Network/    Weather + Places services
│   └── Firebase/   Auth + Firestore services
├── Models/         Codable data models
├── ViewModels/     MVVM view models
├── Views/          SwiftUI screens
├── Resources/      .mlmodel
└── Config/         Config.swift, APIKeys.plist, Theme.swift
```

## Firestore security rules
Rules live in [firestore.rules](firestore.rules): an authenticated user can only
read/write their own `users/{uid}` document and `users/{uid}/trips/{tripId}`;
everything else is denied.

Deploy either way:
- **Console**: Firebase Console → Firestore Database → Rules → paste the contents → Publish.
- **CLI**: `npm i -g firebase-tools && firebase login && firebase deploy --only firestore:rules`
  (uses [firebase.json](firebase.json)).

## Toolchain notes (Xcode 14.3.1)
- Deployment target **iOS 16.0**.
- Firebase is pinned to **10.23.0** with **nanopb forced to 2.30909.0** (a direct SPM
  dependency) — required because newer nanopb declares iOS 12 while Firebase's manifest
  declares iOS 11, which Xcode 14.3.1's SwiftPM rejects. On Xcode 15+ both pins can be lifted.
- If SwiftPM fails to fetch after clearing caches (`safe.bareRepository` error), build with
  `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all xcodebuild …`.

## Build status
All 15 build-order steps complete; the app builds green for the iOS Simulator.

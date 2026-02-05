# 📱 Social App (Flutter)

## 🚀 Overview

This Flutter social app allows users to:

* Create and interact with posts
* Share stories
* Chat with other users in real time
* Receive notifications
* Manage profiles and social relationships

The emphasis is on **engineering quality**, **maintainability**, and **real-world mobile patterns**, rather than experimental features.

---

## 🧩 Features

#### Authentication
* Firebase Authentication (email/password)
* Persistent login sessions
#### Social Feed
* Create and view posts
* Like and comment functionality
* Optimized feed rendering
#### Stories
* Story-style ephemeral content
* Media upload support
#### Messaging
* 1:1 conversations
* Real-time chat updates via Firestore
* Media and video message support
#### Notifications
* Push notifications using Firebase Cloud Messaging
* In-app notification tracking
#### User Management
* User profiles
* Block and unblock users
* Contact and conversation management
---

## 🏗 Architecture

The app follows a **clean, modular Flutter architecture** designed for growth:

```
lib/
├── main.dart
├── constants.dart
├── model/          # Firestore-backed data models
├── services/       # Firebase & backend abstractions
└── ...
```

#### Design Principles

* Strongly typed domain models
* Centralized Firebase access layer
* Minimal business logic in UI widgets
* Predictable data flow

---

## 🛠 Tech Stack

**Client**

* Flutter (Dart)

**Backend / Services**

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Firebase Cloud Messaging

**Utilities**

* Localization support (`easy_localization`)
* Collection helpers

---

## 📦 Data Models

The project includes structured models for:

* Users
* Posts
* Stories
* Conversations
* Messages
* Reactions
* Notifications
* Blocked users

All models are designed to map directly to Firestore documents and support real-time updates.

---

## ⚙️ Setup & Installation

#### Prerequisites

* Flutter SDK
* Android Studio or Xcode
* A configured Firebase project

#### Steps

1. Clone the repository
2. Install dependencies:

   ```bash
   flutter pub get
   ```
3. Configure Firebase:

   * Add `google-services.json` for Android
   * Add `GoogleService-Info.plist` for iOS
4. Run the app:

   ```bash
   flutter run
   ```

---

## 🔐 Firebase Setup Notes

Required Firebase services:

* Authentication (Email/Password)
* Cloud Firestore
* Firebase Storage
* Cloud Messaging

Firestore rules should restrict access to authenticated users only.

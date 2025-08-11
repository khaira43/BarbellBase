# 🏋️‍♂️ FitnessApp

A SwiftUI-based fitness tracking app that allows users to create, manage, and view workouts and routines, with Firebase authentication for secure login and user management.  

## 📌 Features

### 🔐 Authentication
- User registration & sign-in with **Firebase Authentication**
- Password reset, email update, and password update functions
- User session management with `AuthenticationManager`

### 🏋️ Workouts & Routines
- Create new workouts with **exercise lists**
- Organize workouts by **day of the week**
- View recent workouts and saved routines
- Scrollable horizontal lists for quick navigation

### 👤 Profile
- View logged-in user details (e.g., `UserId`)
- Profile management section (gear icon placeholder for settings)

### 🎨 UI / UX
- **SwiftUI** interface with custom color scheme (dark navy background, yellow highlights)
- Responsive layouts for multiple screen sizes
- Custom tab bar navigation with icons for Stats, Friends, Workout, Profile, and Goals

---

## 🛠️ Tech Stack

- **SwiftUI** – UI framework
- **Firebase Auth** – User authentication
- **MVVM Architecture** – Separation of logic and views
- **Async/Await** – Modern concurrency in Swift
- **NavigationStack** & **NavigationLink** for navigation
- Custom hex-based color extension for theming

---

## 📂 Project Structure

FitnessApp/
│
├── AuthenticationManager.swift # Handles all Firebase authentication logic
├── AddExerciseView.swift # View for adding exercises to a workout
├── NewWorkoutView.swift # Create a new workout with a list of exercises
├── ProfileView.swift # Shows current user info and profile actions
├── RoutineView.swift # Weekly workout planner view
├── WorkoutView.swift # Main workout hub with routines & recent workouts


---

## 🚀 Getting Started

### 1️⃣ Requirements
- macOS with Xcode 15+
- iOS 17+ deployment target
- A Firebase project set up in the [Firebase Console](https://console.firebase.google.com)

### 2️⃣ Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/FitnessApp.git
   cd FitnessApp

Open the .xcodeproj or .xcworkspace file in Xcode.

3️⃣ Firebase Setup
In the Firebase Console, create a new project.

Enable Email/Password Authentication in Firebase Authentication settings.

Download the GoogleService-Info.plist file from Firebase and add it to your Xcode project.

Add Firebase to your project using Swift Package Manager:

Go to File > Add Packages

Enter: https://github.com/firebase/firebase-ios-sdk

Select the FirebaseAuth package.

4️⃣ Run the App
Select a simulator or a connected device in Xcode.

Press Cmd + R to build and run.

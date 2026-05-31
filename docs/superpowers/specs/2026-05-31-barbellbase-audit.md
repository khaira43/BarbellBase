# BarbellBase Audit & Roadmap

**Date:** 2026-05-31
**Status:** Audit — no code changes yet
**Scope:** Inventory of broken, stubbed, and missing functionality in the current `main` branch, ordered by impact, with a recommended sequence of work.

---

## 1. State of the app

BarbellBase is a SwiftUI fitness app with Firebase Auth + Firestore. The auth flow and visual design (navy `#081f3a` + yellow) are intentional and working. Everything past sign-in is scaffolding: views render, but most actions are no-ops and no workout data persists.

The app has roughly the right *shape* for a fitness tracker but none of the load-bearing pieces (active session, persistence, exercise model) are implemented yet.

---

## 2. Bugs (working incorrectly — fix first)

### B1. Sign-in destructively overwrites the Firestore user doc
`LoginView.signIn()` (`LoginView.swift:30`) calls `UserManager.createNewUser(user:)`, which uses `setData(merge: false)`. Every sign-in wipes `isPremium` (and any future user fields) back to defaults. A returning premium user loses their premium status on every login.

**Fix:** Sign-in should not write to Firestore. Only `signUp()` should call `createNewUser`. Optionally `createNewUser` should be a no-op (or `merge: true` with `setData(from:merge:)`) if a doc already exists.

### B2. Sign-up does not create a Firestore user doc
`SignUpView` (`SignUpView.swift:113`) calls `AuthenticationManager.createUser` directly but never calls `UserManager.createNewUser`. New users who go through the sign-up sheet have an Auth account but no Firestore document — `ProfileView.loadCurrentUser` will throw on their first profile visit.

**Fix:** `SignUpView` should call the same `viewModel.signUp()` path that's defined in `SignInEmailViewModel` (currently unused), so the Firestore doc is created.

### B3. Tab bar leads to ProfileView for every tab
In `WorkoutView.swift:174-204` and `RoutineView.swift:410-426`, all five tab destinations (`Stats`, `Friends`, `Workout`, `Profile`, `Goals`) are wired to `ProfileView`. The tab bar visually highlights the selected tab but doesn't navigate anywhere meaningful.

**Fix:** Either replace with a real `TabView` at the app root, or wire destinations to the right screens (and gate non-existent ones with a placeholder).

### B4. SignUpView doesn't dismiss on success
After a successful sign-up, the sheet stays open showing the success message. The user has to manually swipe down, then sign in.

**Fix:** Either auto-dismiss after a brief delay, or transition straight into the signed-in state.

### B5. `LoginView` uses deprecated `NavigationLink(isActive:)`
`LoginView.swift:194` uses the iOS 16-deprecated API. Compiles with warnings; should migrate to `.navigationDestination(isPresented:)` or a value-based stack.

---

## 3. Stubs (visible UI that does nothing — wire up next)

### S1. "Start Today's Workout" button is empty
`WorkoutView.swift:32` — empty action closure. Highest-visibility dead button in the app.

### S2. `NewWorkoutView` Save button is empty
`NewWorkoutView.swift:55` — `Button("Save") { /* Save workout logic */ }`. Workouts cannot be created.

### S3. Routines and recent workouts are `@State`, not persisted
`WorkoutView.swift:11-12` — local arrays that reset on every launch. No Firestore collection exists for them yet.

### S4. Exercises are `[String]`
`NewWorkoutView.swift:14` and `AddExerciseView.swift:12`. There is no sets/reps/weight model. This blocks every meaningful workout feature.

### S5. No sign-out anywhere in the UI
`AuthenticationManager.signOut()` exists but no view calls it. The `showSignInView` binding in `ProfileView` is plumbed but never written to.

### S6. Settings gear icon is decorative
`ProfileView.swift:58` — an `Image`, not a `Button` or `NavigationLink`.

### S7. `ProfileView` is a debug screen
Shows raw `userId`, anonymous flag, and a premium toggle. No display name, email, avatar, or sign-out. This is the screen most users will see most often.

---

## 4. Dead code / cleanup

### C1. `ContentView.swift` is the Xcode default
Still says "Hello, world!". Not referenced anywhere. Delete.

### C2. `NewWorkout.swift` is a one-line stub
Also "Hello, world!". Distinct from `NewWorkoutView.swift`. Delete.

### C3. `RoutineView.swift` duplicates the same day-section seven times
~350 lines of copy-paste, with `Workouts1`…`Workouts7` instead of a `[Weekday: [Workout]]` map. Replace with a `ForEach(Weekday.allCases)` and a single `DaySection` subview.

### C4. Commented-out dead code in `UserManager`, `WorkoutView`, `LoginView`
Several large commented blocks (old API attempts). Once the corresponding live code is settled, delete these — they make the files hard to read.

### C5. `Workout` and `Routine` models are name-only stubs
`WorkoutView.swift:264-272`. Will need real fields once persistence lands; flagging here so it's not forgotten.

---

## 5. Missing features (need designing, not just wiring)

These are not bugs — they're whole features the app implies but doesn't have. Each needs its own brainstorm + spec before implementation.

### M1. Active workout session
The core of any fitness app. Tap an exercise, log set / reps / weight, rest timer, mark workout complete. This is what "Start Today's Workout" should open.

### M2. Exercise library / catalog
A canonical list of exercises (Bench Press, Squat, etc.) so users pick from a list rather than typing free text every time. Likely seeded data + search.

### M3. Workout history
The "Recent Workouts" row needs a source. Completed sessions from M1 land here. Tap to view the session log.

### M4. Stats tab
Volume over time, PRs, streaks, body-part frequency. Depends on M3 having data.

### M5. Goals tab
TBD whether this is target weights per lift, weekly workout count, or body composition.

### M6. Friends tab
Social — feed, follows, leaderboards. Largest scope; could be cut from v1 entirely.

### M7. Routine → schedule binding
The current `RoutineView` shows seven empty day slots but there is no defined relationship between a routine and a weekday, and no "today's routine" lookup that the workout button could read.

---

## 6. Recommended sequence

Numbered groups; later groups depend on earlier ones.

**Group 1 — Bug fixes (1-2 hours, no design needed):**
B1, B2, B4, B5, B3 *(B3 first if a real `TabView` is wanted, last if just placeholder views)*.
Goal: auth flow doesn't lose data, navigation isn't a lie.

**Group 2 — Cleanup (30 min):**
C1, C2, C4. Defer C3 to Group 3.

**Group 3 — Data layer & persistence:**
Design a `Workout` / `Exercise` / `Set` model (replaces S4 + C5). Add Firestore collections and a `WorkoutManager` mirroring `UserManager`. Refactor `RoutineView` (C3) onto the new model. Wire `NewWorkoutView` Save (S2) and the routine/recent-workout sources (S3).
**This is the largest single block of work — should get its own brainstorm + spec.**

**Group 4 — Profile polish:**
Sign-out button (S5), settings nav (S6), real profile fields (S7). Small.

**Group 5 — Active workout session (M1):**
Depends on Group 3 data model. Probably the biggest feature in the whole app. Own spec.

**Group 6 — Library, history, stats:**
M2 → M3 → M4 in that order. Each is a real feature.

**Defer / decide later:**
M5 (Goals) and M6 (Friends) — confirm whether these are in scope before designing.

---

## 7. Open questions for the user

1. **Tab bar architecture:** real `TabView` at the app root, or keep the custom bottom bar inside each screen? (Affects how B3 gets fixed and how M4/M5/M6 plug in.)
2. **Routines vs. workouts:** is a "routine" a named weekly schedule (Mon = Push, Wed = Pull…) or a reusable template (a "Push Day" you can run any day)? This shapes the data model in Group 3.
3. **Are Goals and Friends real features for v1, or should those tabs be cut?**
4. **Exercise catalog:** seed a fixed list, or let users add custom exercises freely from the start?

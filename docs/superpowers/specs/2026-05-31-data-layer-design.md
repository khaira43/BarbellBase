# Data Layer Design — Workouts, Exercises, Schedule

**Date:** 2026-05-31
**Status:** Design — awaiting user approval
**Scope:** Group 3 from the audit (`2026-05-31-barbellbase-audit.md`). Establishes the persistent data model and the manager classes needed to support Workout templates, an Exercise catalog, and a weekly Schedule. Wires up the Save button in `NewWorkoutView` and makes `WorkoutView` / `RoutineView` read real data instead of empty `@State`.

**Explicitly NOT in scope:** active workout session (Group 5 / M1) and Stats/Goals/Friends features. The model is designed so those layers can be added cleanly later.

---

## 1. Concept model

Three persistent entities and one in-memory catalog:

```
ExerciseCatalogItem (in-memory + Firestore for custom)
        │
        ▼ referenced by
PlannedExercise (value type inside WorkoutTemplate)
        │
        ▼ contained in
WorkoutTemplate (Firestore: users/{uid}/workoutTemplates/{id})

Schedule (Firestore: users/{uid}/schedule/main)
  └── Weekday → WorkoutTemplate.id
```

- **`ExerciseCatalogItem`** — one entry in the exercise picker. Either bundled (Bench Press, Squat…) or user-added.
- **`PlannedExercise`** — one row inside a workout template ("Bench Press, 4 sets × 8 reps, target 135 lbs"). References a catalog item by id.
- **`WorkoutTemplate`** — a reusable named workout the user assembled (e.g. "Push Day"). Owns an ordered list of `PlannedExercise`.
- **`Schedule`** — a single doc per user mapping each weekday to at most one `WorkoutTemplate.id`. "Today's Workout" reads this.

This shape matches the user's stated intent: customizable workouts AND a customizable weekly schedule (see `[[project-routine-vs-workout-model]]` in memory).

---

## 2. Swift types

All in a new `fitnessApp/Models/` directory.

```swift
// Models/ExerciseCategory.swift
enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, legs, core, cardio, other
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// Models/ExerciseCatalogItem.swift
struct ExerciseCatalogItem: Codable, Identifiable, Hashable {
    let id: String              // "bench_press" (seeded) or UUID (custom)
    let name: String            // "Bench Press"
    let category: ExerciseCategory
    let isCustom: Bool          // true if user-added
}

// Models/PlannedExercise.swift
struct PlannedExercise: Codable, Identifiable, Hashable {
    let id: String              // UUID per row, stable across edits
    let exerciseId: String      // -> ExerciseCatalogItem.id
    let exerciseName: String    // denormalized for display without catalog lookup
    var targetSets: Int         // default 3
    var targetReps: Int         // default 8
    var targetWeight: Double?   // optional; nil means bodyweight or unknown
}

// Models/WorkoutTemplate.swift
struct WorkoutTemplate: Codable, Identifiable, Hashable {
    let id: String              // UUID
    let userId: String
    var name: String
    var exercises: [PlannedExercise]
    let dateCreated: Date
    var dateUpdated: Date
}

// Models/Schedule.swift  (replaces the current Weekday enum location)
enum Weekday: String, Codable, CaseIterable, Identifiable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    static var today: Weekday { /* Calendar lookup */ }
}

struct Schedule: Codable {
    let userId: String
    var assignments: [Weekday: String]  // workoutTemplateId per day
}
```

**Notes:**
- `exerciseName` on `PlannedExercise` is intentionally denormalized. A renamed catalog item should NOT silently rename it in existing templates. The catalog provides the picker; the template owns its own copy of the name at save time.
- `targetWeight` is `Double?`. Bodyweight exercises (push-up, pull-up) have no target weight. Unit (lbs vs kg) is deferred to a per-user setting later; values stored as whatever the user enters, displayed as-is for now.
- `Schedule` is one doc, not seven. Cheap to fetch, atomic to update.
- The old `Weekday` enum in `RoutineView.swift` moves into `Models/`.

---

## 3. Firestore shape

```
users/{uid}                                   (existing — DBUser)
users/{uid}/workoutTemplates/{templateId}     WorkoutTemplate
users/{uid}/customExercises/{exerciseId}      ExerciseCatalogItem  (only isCustom == true)
users/{uid}/schedule/main                     Schedule
```

**Key encoding:** stay consistent with `DBUser` and use snake_case at the Firestore boundary via explicit `CodingKeys`. For nested value types (`PlannedExercise` inside `WorkoutTemplate.exercises`), Firestore's Codable bridge will encode them as a nested array of maps automatically — no per-field codingKeys needed unless we want to rename for storage.

**Schedule encoding:** `assignments` becomes a `[String: String]` map at the Firestore layer (Weekday raw value → templateId). Days without an assignment are absent from the map (not `null`).

---

## 4. Seeded exercise catalog

Ship `fitnessApp/Resources/SeededExercises.json` in the app bundle. ~40 entries covering common compound + accessory lifts. Loaded once at app launch into `ExerciseCatalog.shared.seeded`.

Example shape:
```json
[
  {"id": "barbell_back_squat", "name": "Barbell Back Squat", "category": "legs"},
  {"id": "bench_press", "name": "Bench Press", "category": "chest"},
  {"id": "deadlift", "name": "Deadlift", "category": "back"},
  {"id": "overhead_press", "name": "Overhead Press", "category": "shoulders"},
  ...
]
```

Seeded ids are stable strings (`bench_press`) so they're greppable and don't drift across reinstalls. Custom exercises use UUIDs.

**Initial seed list (~40 items):** squat, front squat, deadlift, romanian deadlift, bench press, incline bench, dumbbell bench, overhead press, push press, barbell row, dumbbell row, pull-up, chin-up, lat pulldown, seated row, hip thrust, leg press, leg curl, leg extension, calf raise, lunge, bulgarian split squat, lateral raise, rear delt fly, face pull, dumbbell curl, barbell curl, hammer curl, tricep pushdown, skull crusher, dip, plank, hanging leg raise, ab wheel, russian twist, push-up, treadmill, stationary bike, rowing machine, elliptical. (Final list finalized at implementation time.)

---

## 5. Manager classes

Mirror the existing `UserManager` / `AuthenticationManager` singleton pattern.

```swift
// Firestore/ExerciseCatalog.swift
final class ExerciseCatalog: ObservableObject {
    static let shared = ExerciseCatalog()
    @Published private(set) var items: [ExerciseCatalogItem] = []

    func loadSeeded()                                 // sync, from bundle JSON
    func loadCustom(userId: String) async throws      // pulls user's custom exercises
    func addCustom(_ item: ExerciseCatalogItem) async throws
    func search(_ query: String) -> [ExerciseCatalogItem]   // local filter
}

// Firestore/WorkoutTemplateManager.swift
final class WorkoutTemplateManager {
    static let shared = WorkoutTemplateManager()
    func createTemplate(_ template: WorkoutTemplate) async throws
    func updateTemplate(_ template: WorkoutTemplate) async throws
    func deleteTemplate(userId: String, templateId: String) async throws
    func getTemplate(userId: String, templateId: String) async throws -> WorkoutTemplate
    func listTemplates(userId: String) async throws -> [WorkoutTemplate]
}

// Firestore/ScheduleManager.swift
final class ScheduleManager {
    static let shared = ScheduleManager()
    func getSchedule(userId: String) async throws -> Schedule    // returns empty Schedule if none
    func assignWorkout(userId: String, day: Weekday, templateId: String?) async throws
    func setSchedule(_ schedule: Schedule) async throws          // full replace
}
```

`ExerciseCatalog` is `ObservableObject` because the picker UI subscribes to changes when a user adds a custom exercise mid-flow. The other two are not observable — views fetch on appear.

---

## 6. View changes

### 6.1 `AddExerciseView` — rebuild
Currently: takes a free-text exercise name string. Becomes: a searchable picker over `ExerciseCatalog.items`, with a target-sets / target-reps / target-weight field set. Result is a `PlannedExercise`, not a string. Includes an "Add new exercise" affordance that pushes a small `CreateCustomExerciseView` for naming + category, persists it via `ExerciseCatalog.addCustom`, then auto-selects it.

### 6.2 `NewWorkoutView` — wire Save
- Replace `@State exercises: [String]` with `@State exercises: [PlannedExercise]`.
- Add a `workoutName` text field (already present).
- Save button: builds a `WorkoutTemplate`, calls `WorkoutTemplateManager.createTemplate`, dismisses.
- Use a `NewWorkoutViewModel` to keep the view dumb (mirrors `ProfileViewModel`).

### 6.3 `WorkoutView` — read real data
- `@StateObject WorkoutViewModel` loads templates on appear via `WorkoutTemplateManager.listTemplates`.
- "Routines" row shows the user's templates (taps go to a `WorkoutTemplateDetailView` — new, simple read-only screen for now).
- "Recent Workouts" row will be empty in this milestone (depends on Group 5 sessions). Leave the "Create Workout" placeholder for now and note the dependency in code.
- "Start Today's Workout" button: looks up `Weekday.today` in the Schedule, finds the template, opens the detail view. (Active session integration is Group 5 — for this milestone, tapping it just navigates to the assigned template, or shows a "no workout scheduled" message.)

### 6.4 `RoutineView` — read/write real Schedule
- `@StateObject ScheduleViewModel` loads schedule on appear, also loads the template list (needed to display names).
- Each day section shows the assigned template's name (or "Add Workout" if unassigned).
- Tapping "Add Workout" on a day opens a small `AssignWorkoutSheet` listing the user's templates; selection writes via `ScheduleManager.assignWorkout`.
- Tapping an assigned template lets the user clear or replace it.
- Rename internal label "RoutineView" → no, keep file name for now; it IS the schedule view but renaming would touch the TabView tabItem. Defer rename until Group 4 cleanup.

---

## 7. Migration & backfill

There is no production data — the app has never persisted workouts (`routines` and `recentWorkouts` are `@State`). No migration needed.

The existing local `Workout` and `Routine` structs in `WorkoutView.swift` are deleted in favor of the new models.

---

## 8. Error handling

- Manager errors propagate via `throws`. View models catch and set `@Published var errorMessage: String?` for surface display.
- No silent fallbacks. A failed load shows an error row; a failed save keeps the user on the form so they don't lose input.
- Idempotency: `createTemplate` uses a UUID generated at view-model time, so a retry after a transient failure does NOT create duplicates (the same id is reused). `assignWorkout` is naturally idempotent (overwrite).

---

## 9. Testing approach

Unit tests are not wired up in this project yet (the existing test files are empty Xcode templates). For this milestone I'll defer adding tests and rely on manual verification + `xcodebuild`. **Open question for the user (Q1 below)** — do you want me to add a real test target setup as part of this work?

Manual verification path:
1. Build + run on simulator.
2. Sign up a new account.
3. Workout tab → "Add Routine" → name it "Push Day", add 3 exercises (one from catalog, one custom), save.
4. Workout tab → confirm "Push Day" shows in Routines row.
5. Workout tab → tap RoutineView (still nested), assign "Push Day" to Monday.
6. Sign out, sign back in. Confirm template + schedule persisted.

---

## 10. File structure (new + changed)

```
fitnessApp/
├── Models/                              [NEW dir]
│   ├── ExerciseCategory.swift
│   ├── ExerciseCatalogItem.swift
│   ├── PlannedExercise.swift
│   ├── WorkoutTemplate.swift
│   ├── Weekday.swift                    (moved from RoutineView.swift)
│   └── Schedule.swift
├── Firestore/
│   ├── UserManager.swift                (unchanged)
│   ├── ExerciseCatalog.swift            [NEW]
│   ├── WorkoutTemplateManager.swift     [NEW]
│   └── ScheduleManager.swift            [NEW]
├── Resources/                           [NEW dir]
│   └── SeededExercises.json             [NEW]
├── Workout/
│   ├── WorkoutView.swift                (rewritten — uses VM)
│   ├── NewWorkoutView.swift             (rewritten — uses VM)
│   ├── AddExerciseView.swift            (rewritten — picker + targets)
│   ├── CreateCustomExerciseView.swift   [NEW]
│   └── WorkoutTemplateDetailView.swift  [NEW]
├── Schedule/                            [NEW dir]
│   ├── RoutineView.swift                (moved + rewritten)
│   └── AssignWorkoutSheet.swift         [NEW]
├── ProfileView.swift                    (unchanged)
├── SettingsView.swift                   (unchanged)
├── RootTabView.swift                    (unchanged)
└── ...
```

Reorganizing existing `WorkoutView.swift` / `NewWorkoutView.swift` / `AddExerciseView.swift` into a `Workout/` subdirectory while we're here, and moving `RoutineView.swift` to `Schedule/`. Both directories will be picked up by the synced root group automatically.

---

## 11. Open questions for the user

1. **Tests:** add a real unit-test target for the managers in this milestone, or defer? (I lean: defer, focus on shipping features. Easy to add later.)
2. **Weight units:** lbs only for now, or store kg-or-lbs flag per user from the start? (I lean: lbs only, store as `Double`, add a setting later.)
3. **Schedule rename:** is "Routine" tab the right label, or should the file/screen be renamed to "Schedule"? The current label says "Routine" but the *thing* is really a weekly schedule of routines. (I lean: leave the label "Routine" for now since it's user-facing copy and the schedule-of-templates model still fits the word.)
4. **Workout template detail screen:** for v1, read-only display of the template's exercises is fine, right? Editing an existing template can come later. (I lean: yes, read-only for v1, since editing means more form work.)

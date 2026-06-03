# Active Workout Session — Design (Group 5)

Date: 2026-06-03
Status: approved
Predecessors: `2026-05-31-barbellbase-audit.md`, `2026-05-31-data-layer-design.md`

## Goal

Make BarbellBase demoable end-to-end by replacing the broken "Start Today's Workout" flow with a real, full-screen active session: log sets live, rest timer between sets, finish to a summary screen, and surface the finished session in the Workout tab's Recent Workouts row.

## Scoping decisions (locked in during brainstorming)

| Decision | Choice |
|---|---|
| Mid-session edit scope | Add/remove sets only. Exercises are locked to what the template planned. |
| Rest timer | Fixed 90s, auto-starts when a set is marked complete. Adjustable with −15s / +15s / Skip. |
| Start entry | "Start Today's Workout" on Workout tab AND a "Start Workout" button on the existing-template editor. No freestyle/empty session. |
| Finish flow | Summary screen (duration / sets / volume) → "Done" returns to Workout tab; Recent Workouts updates. |
| Presentation | Full-screen `.fullScreenCover` modal. Tab bar hidden during the session. |

## Data model

Three new types in `fitnessApp/Models/`. All `Codable` with snake_case `CodingKeys` matching existing convention.

### `LoggedSet`

One set within an exercise.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `targetReps` | `Int` | Denormalized from `PlannedExercise` at session start |
| `targetWeight` | `Double?` | Denormalized |
| `actualReps` | `Int` | Defaults to `targetReps`, editable |
| `actualWeight` | `Double?` | Defaults to `targetWeight`, editable |
| `isCompleted` | `Bool` | |
| `completedAt` | `Date?` | Set when `isCompleted` flips to true |

### `LoggedExercise`

One exercise within a session.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID, distinct from `PlannedExercise.id` so repeating a template doesn't collide |
| `exerciseId` | `String` | Catalog id |
| `exerciseName` | `String` | Denormalized — survives catalog rename/delete |
| `sets` | `[LoggedSet]` | |

### `WorkoutSession`

The session itself.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `userId` | `String` | |
| `templateId` | `String?` | The template it started from (nullable to allow future freestyle) |
| `templateName` | `String` | Denormalized |
| `startedAt` | `Date` | |
| `completedAt` | `Date?` | `nil` while in progress, set on Finish |
| `exercises` | `[LoggedExercise]` | |

### Builder helper

```swift
extension WorkoutSession {
    static func starting(from template: WorkoutTemplate, userId: String) -> WorkoutSession
}
```

Copies `template.name` → `templateName`, and each `PlannedExercise`'s `name`/`targetSets`/`targetReps`/`targetWeight` into a `LoggedExercise` with that many `LoggedSet`s (one per target set), `isCompleted: false`, `actualReps == targetReps`, `actualWeight == targetWeight`. Sets `startedAt = Date()`, `completedAt = nil`.

## Firestore shape

- Path: `users/{uid}/sessions/{sessionId}`
- Written exactly once, on Finish, with `merge: false`
- In-progress sessions stay in memory only (`ActiveSessionViewModel`'s `@Published` state)
- Force-closing the app mid-session loses the workout (acceptable for v1, no Firestore residue)

## Manager API

New `Firestore/WorkoutSessionManager.swift`, mirrors the existing `WorkoutTemplateManager` singleton pattern.

```swift
@MainActor
final class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
    private init() {}

    func saveCompletedSession(_ session: WorkoutSession) async throws
    func listRecentSessions(userId: String, limit: Int = 5) async throws -> [WorkoutSession]
    func getSession(userId: String, sessionId: String) async throws -> WorkoutSession
}
```

- `saveCompletedSession` writes to `users/{uid}/sessions/{id}` with `merge: false`. Expects `completedAt != nil`.
- `listRecentSessions` queries ordered by `completed_at` desc, limited to 5 for the Recent Workouts row.
- `getSession` powers tapping a Recent Workouts card to view it read-only.

## UI

### Entry points

1. **`WorkoutView`** — "Start Today's Workout" button changes from `NavigationLink(WorkoutTemplateEditorView)` to a `.fullScreenCover` presenting `ActiveSessionView(template:)`. Only enabled when `viewModel.todaysTemplate != nil`.
2. **`WorkoutTemplateEditorView`** (edit mode only, i.e. `isEditing == true`) — add a "Start Workout" button above "Delete Workout" that presents the same `.fullScreenCover`. Routine circle tap → editor → Start.

### `ActiveSessionView` layout

Full-screen, no nav bar, custom top bar:

- **Top bar:** template name, elapsed time clock (`mm:ss`), close ✕ button on the right
- **Scrollable exercise list,** one card per `LoggedExercise`:
  - Header: exercise name + "completed / total" set count
  - One row per `LoggedSet`: `[☐] Set N   Reps: [12]   Weight: [135 lbs]`
  - `Reps` and `Weight` are inline `TextField`s pre-filled with `actualReps` / `actualWeight`, editable
  - Tapping the checkbox marks the set complete, dims/strikes through the row, triggers the rest timer
  - "+ Add Set" link below the last set; new set copies the previous set's values as defaults
  - Swipe-to-delete on any set row (uses `.swipeActions`)
- **Sticky bottom bar:** "Finish Workout" button. Disabled until `canFinish` (at least one set completed).

### Rest timer pill

When a set is completed, a pill slides up from the bottom (above Finish) showing "Rest: 1:30" counting down. Buttons: `−15s`, `+15s`, `Skip`. Auto-dismisses at 0:00 with a soft haptic. Tapping another set's checkbox while the timer is running cancels the current timer task and starts a fresh 90s timer.

### Close / discard

Tapping ✕ → confirmation alert: "Discard workout? Your logged sets won't be saved." → Cancel / Discard. Discard dismisses the modal without writing to Firestore.

### Finish

Tap Finish → `viewModel.finish()` → calls `WorkoutSessionManager.saveCompletedSession`. On success, the modal body transitions to `SessionSummaryView`. On failure, an inline error is shown and the session stays intact for retry.

### `SessionSummaryView`

Reused for two roles:
- **Finish:** shown inside the same `.fullScreenCover` after a successful save. Button reads "Done", dismisses the modal.
- **Recent Workouts tap:** shown via `.sheet` from `WorkoutView`. Button reads "Close", dismisses the sheet.

Layout:

- **Header:** "Workout Complete" (Finish mode) or template name (read-only mode); subtitle is template name + formatted date
- **Stat row:** three tiles — Duration (`mm:ss` between `startedAt` and `completedAt`), Sets Completed (`X/Y`), Total Volume (sum of `actualReps × actualWeight` across completed sets; non-completed sets ignored)
- **Exercise breakdown:** read-only list, one card per `LoggedExercise`, each showing only its completed sets as `Set N — 12 × 135 lbs`
- **Bottom button:** "Done" / "Close"

### Recent Workouts row in `WorkoutView`

Replaces the existing "Coming Soon" placeholder.

- `WorkoutListViewModel` gains `@Published private(set) var recentSessions: [WorkoutSession] = []`
- `load()` adds `async let recentTask = WorkoutSessionManager.shared.listRecentSessions(userId: uid, limit: 5)` alongside templates + schedule
- Each session renders as a card: circle with template's first letter, name underneath, small date subtitle ("Today" / "Yesterday" / "Jun 1")
- Tap → `.sheet` presenting `SessionSummaryView(session:, mode: .readOnly)`
- Empty state: placeholder card with "No workouts logged yet"
- Modal dismiss in `WorkoutView` triggers `await viewModel.load()` so the row refreshes

## State management

`ActiveSessionViewModel` is `@MainActor` `ObservableObject` and owns the session in memory:

```swift
@Published var session: WorkoutSession
@Published var elapsedSeconds: Int = 0
@Published var restRemaining: Int? = nil   // nil when no rest active
@Published var errorMessage: String?
@Published var isSaving: Bool = false
```

**Elapsed clock:** a single `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` ticks `elapsedSeconds`. On `scenePhase` resume, `elapsedSeconds` is recomputed from `Date().timeIntervalSince(session.startedAt)` so backgrounding doesn't desync the clock.

**Rest timer task:** when a set is toggled complete, the VM cancels any in-flight rest `Task` and starts a new one:

```swift
restTask = Task {
    restRemaining = 90
    while let r = restRemaining, r > 0, !Task.isCancelled {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        restRemaining = r - 1
    }
    restRemaining = nil
    // soft haptic
}
```

Cancellation handles the "tap another set while timer running" reset and the Skip button.

**Computed helpers:** `totalVolume`, `completedSetCount`, `totalSetCount`, `canFinish` (≥ 1 completed set).

## Edge cases

- **Double-tap Finish:** `isSaving` gate disables the button immediately on first tap.
- **Empty exercise name from a deleted catalog item:** still works — name is denormalized on `LoggedExercise` at session start.
- **Save failure:** modal stays open, error shown, session preserved for retry.
- **Backgrounding the app:** `Timer.publish` pauses; on resume, `elapsedSeconds` recomputed from `startedAt`. The rest-timer `Task.sleep` is best-effort during backgrounding — iOS may suspend the task, so `restRemaining` can drift from wall-clock time after a long background. The Skip button is the documented escape hatch. The session itself is unaffected (only the visual countdown).
- **Force-close mid-session:** workout is lost, no Firestore residue.
- **Template deleted mid-session:** session continues because the relevant data is denormalized; on save, `templateId` may point at nothing, but `templateName` keeps the summary readable.

## What this fixes

- B-grade audit item: "Start Today's Workout opens the editor instead of a session"
- Workout tab's "Recent Workouts: Coming Soon" placeholder

## What this does NOT address (acceptable for v1)

- Stale Schedule references after a template is deleted (existing known debt, unchanged)
- Stats tab data wiring (Group 6)
- Pause/resume across launches; Apple Watch; PR detection
- Editing a finished session — sessions are immutable after Finish
- Sharing / social posting
- Templates auto-updating from "best ever" actuals
- Per-exercise rest durations (timer is a fixed 90s)

## Files touched

**New:**
- `fitnessApp/Models/LoggedSet.swift`
- `fitnessApp/Models/LoggedExercise.swift`
- `fitnessApp/Models/WorkoutSession.swift` (includes the `starting(from:userId:)` builder)
- `fitnessApp/Firestore/WorkoutSessionManager.swift`
- `fitnessApp/ActiveSessionView.swift` (view + `ActiveSessionViewModel`)
- `fitnessApp/SessionSummaryView.swift`

**Modified:**
- `fitnessApp/WorkoutView.swift` — replace Start button NavigationLink with `.fullScreenCover`; replace Recent Workouts placeholder with real data; add `.sheet` for tapping a recent session; `WorkoutListViewModel.load()` fetches recent sessions
- `fitnessApp/WorkoutTemplateEditorView.swift` — add "Start Workout" button (edit mode only) above "Delete Workout", presents the same `.fullScreenCover`

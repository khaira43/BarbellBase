# Goals — Design (M5)

Date: 2026-06-08
Status: proposed
Predecessors: `2026-05-31-barbellbase-audit.md`, `2026-05-31-data-layer-design.md`, `2026-06-03-active-workout-session-design.md`, `2026-06-05-stats-screen-design.md`

## Goal

Replace the `ComingSoonContent` placeholder on the Goals tab with a real screen that lets the user create, track, and complete three kinds of fitness goals: per-lift strength targets, weekly workout frequency, and bodyweight targets. All progress is derived from data the app already captures (workout sessions, logged sets) plus one small new collection (bodyweight entries). No new surfaces outside the Goals tab in v1.

## Scoping decisions (locked in during brainstorming)

| Decision | Choice |
|---|---|
| Goal kinds in v1 | Per-lift strength + weekly frequency + bodyweight (all three). |
| Per-lift target style | e1RM number (e.g. "Bench e1RM ≥ 300 lb"). |
| Frequency target style | Workouts per week, resets each Monday. |
| Body composition scope | Bodyweight only — no body fat %, no measurements. |
| Bodyweight history | Kept as dated entries + trend chart. |
| Log-weight UX | "Log weight" button on the bodyweight goal card. No entry surface outside Goals. |
| Active goal counts | Multiple lift goals (unlimited); singleton for frequency; singleton for bodyweight. |
| Deadlines | Optional on lift + bodyweight goals; not applicable to frequency. |
| Completion behavior | Lift + bodyweight auto-complete when the metric crosses target, move to a "Completed" section. Frequency goals are recurring and never auto-complete. |
| Surfacing | Goals tab only in v1 — no Stats integration, no session-save toasts. |
| Data layout | Single `goals/` collection with a `kind` discriminator; bodyweight entries in their own collection. |
| Progress data flow | Reuse the cached `sessions` array from `StatsViewModel` via `@EnvironmentObject`; bodyweight loads from its own collection. |

## Architecture

`GoalsViewModel` is an `@MainActor` `ObservableObject` owned by `RootTabView` as `@StateObject` and injected into `GoalsView` (and onward to `BodyweightDetailView`) via `@EnvironmentObject`. Owning it at the tab root keeps the cached `goals` + `bodyweightEntries` arrays alive across tab switches.

The VM holds the raw lists and exposes derived progress for each active goal as computed properties — pure functions of `(goal, sessions, entries, now)`. There's no separate "goals snapshot" Firestore document; we trade two fetches on first load for never having to worry about aggregate drift.

Progress for `lift` and `frequency` goals reads from `StatsViewModel.sessions` (already cached from the existing Stats infrastructure). Progress for `bodyweight` goals reads from `GoalsViewModel.bodyweightEntries`. The VM subscribes to three notifications and reloads on each:

- `WorkoutSessionManager.sessionSavedNotification` — a new session may cross a lift target or bump the frequency count.
- `GoalsManager.goalSavedNotification` — created / edited / completed.
- `GoalsManager.bodyweightEntrySavedNotification` — a new weight log may cross a bodyweight target.

Tab switches with no new notification do nothing.

## Data model

Two new Swift models in `fitnessApp/Models/`.

```swift
struct Goal: Identifiable, Codable {
    enum Kind: String, Codable { case lift, frequency, bodyweight }
    enum Status: String, Codable { case active, completed }

    var id: String                   // Firestore doc id
    var kind: Kind
    var createdAt: Date
    var status: Status               // active or completed
    var completedAt: Date?           // set when status flips to completed

    // Optional deadline (lift + bodyweight only; nil for frequency)
    var targetDate: Date?

    // Per-kind fields — exactly one is populated, matching `kind`
    var lift: LiftTarget?
    var frequency: FrequencyTarget?
    var bodyweight: BodyweightTarget?
}

struct LiftTarget: Codable {
    var exerciseId: String           // ExerciseCatalogItem.id (seeded or custom)
    var exerciseName: String         // denormalized for display + rename/delete safety
    var targetE1RM: Double           // lb
}

struct FrequencyTarget: Codable {
    var workoutsPerWeek: Int         // 1...7
}

struct BodyweightTarget: Codable {
    var targetWeightLb: Double
    var startWeightLb: Double        // captured at creation; stable progress denominator
}

struct BodyweightEntry: Identifiable, Codable {
    var id: String
    var weightLb: Double
    var loggedAt: Date
}
```

Notes:
- Optional per-kind fields are the cost of Approach A's single collection. The `kind` discriminator tells callers which field to read; `GoalsManager` decode/encode asserts the matching field is non-nil.
- `exerciseName` is denormalized so a renamed or deleted exercise still displays sensibly on a completed goal.
- `startWeightLb` captured at creation gives a stable denominator: `(current − start) / (target − start)`. The bar doesn't jump if the user edits the target later.
- Units: lb only in v1, matching the rest of the app (`formatWeight` is lb-based).

## Firestore layout

```
users/{uid}/goals/{goalId}                 // active + completed goals, all kinds
users/{uid}/bodyweightEntries/{entryId}    // one doc per logged weight
```

Both collections are user-scoped under the existing `users/{uid}/` namespace. Security rules grant access only to the matching authenticated user — same pattern as `workoutTemplates`, `schedule`, `sessions`.

## `GoalsManager`

A new singleton mirroring `WorkoutSessionManager`'s shape, in `fitnessApp/Firestore/GoalsManager.swift`.

```swift
final class GoalsManager {
    static let shared = GoalsManager()
    static let goalSavedNotification = Notification.Name("GoalsManager.goalSaved")
    static let bodyweightEntrySavedNotification = Notification.Name("GoalsManager.bodyweightEntrySaved")

    // Goals
    func listGoals(userId: String) async throws -> [Goal]
    func createGoal(userId: String, goal: Goal) async throws
    func updateGoal(userId: String, goal: Goal) async throws
    func deleteGoal(userId: String, goalId: String) async throws
    func markCompleted(userId: String, goalId: String, at: Date, silent: Bool) async throws

    // Bodyweight entries
    func listBodyweightEntries(userId: String) async throws -> [BodyweightEntry]
    func latestBodyweight(userId: String) async throws -> BodyweightEntry?
    func logBodyweight(userId: String, weightLb: Double, at: Date) async throws
    func deleteBodyweightEntry(userId: String, entryId: String) async throws
}

enum GoalsError: Error {
    case singletonKindExists(Goal.Kind)
    case invalidTarget
}
```

Behaviors:
- **Singleton enforcement** lives in `createGoal`: for `kind == .frequency` or `.bodyweight`, query for an existing active goal of the same kind first; throw `singletonKindExists` if found. UI prevents this path; manager guard catches races.
- **`markCompleted` is idempotent.** It reads the doc first and no-ops if `status == .completed`. Safe to call from every reload.
- **Notifications** fire after a successful write. `markCompleted(silent: true)` skips the notification to break the auto-complete reload loop.
- **`listBodyweightEntries`** returns entries ordered by `loggedAt` desc.
- **`latestBodyweight`** is a convenience wrapper around the same query with `.limit(1)`.

## Progress evaluation

A pure `GoalsMath` struct lives next to `GoalsViewModel`, mirroring `StatsMath`.

```swift
struct GoalsProgress {
    let percent: Double        // 0.0...1.0, clamped
    let currentDisplay: String // "287 lb e1RM", "3 / 4", "182 lb", "—"
    let targetDisplay: String  // "300 lb", "4/wk", "175 lb"
    let isHit: Bool            // metric has crossed target
}

enum GoalsMath {
    static func liftProgress(goal: Goal, sessions: [WorkoutSession]) -> GoalsProgress
    static func frequencyProgress(goal: Goal, sessions: [WorkoutSession], now: Date) -> GoalsProgress
    static func bodyweightProgress(goal: Goal, entries: [BodyweightEntry]) -> GoalsProgress
}
```

**Lift.** Scan every completed session, every `LoggedExercise` with `exerciseId == goal.lift.exerciseId`, every `LoggedSet`. For each set, compute `StatsMath.epleyOneRepMax(weight: actualWeight, reps: actualReps)` (reusing the existing helper). Track the maximum. `percent = currentMax / targetE1RM`. `isHit = currentMax >= targetE1RM`. Empty case (no logged sets for that exercise yet): percent 0, current "—".

**Frequency.** Compute the current week's Monday 00:00 in the user's local TZ using `Calendar.current` with `firstWeekday = 2`. Count completed sessions where `completedAt ∈ [Monday, Monday + 7d)`. `percent = count / workoutsPerWeek`. `isHit = count >= workoutsPerWeek`. Frequency goals are **recurring** — `isHit` resets each Monday and they never auto-complete.

**Bodyweight.** `current = entries.first?.weightLb`. Direction inferred from `targetWeightLb` vs `startWeightLb`:
- Bulk (`target > start`): `percent = (current − start) / (target − start)`, `isHit = current >= target`.
- Cut (`target < start`): `percent = (start − current) / (start − target)`, `isHit = current <= target`.

Percent always clamps to `[0, 1]`. Empty case (no entries yet): percent 0, current "—".

**Auto-completion trigger.** `GoalsViewModel.evaluateAndPersistCompletions()` runs after every reload. For each active `lift` or `bodyweight` goal where `isHit == true`, the VM calls `GoalsManager.markCompleted(silent: true)`. Frequency goals are skipped.

## UI structure

### `GoalsView` (NavigationStack, on the existing Goals tab)

Top to bottom:

- **Active goals** — flat scrollable list of cards, no inter-kind section headers. Ordering: lift goals first (by `createdAt` desc), then frequency, then bodyweight. Each card carries a kind icon (`dumbbell`, `calendar`, `figure.arms.open`).
- **Completed** — collapsible `DisclosureGroup` titled "Completed (N)". Hidden when N = 0. Each row shows kind icon, what the goal was, the date hit. Swipe-to-delete.

Toolbar trailing item: `+` button → `AddGoalSheet`.

Empty state (zero active and zero completed): `ComingSoonContent`-style placeholder with "No goals yet — tap + to add one."

### Card shapes

**Lift goal card**
- Title: `exerciseName`.
- Big number: `currentE1RM` in lb.
- Progress bar.
- Subtitle: "X of Y lb e1RM".
- Pill: "Due in N days" (or "Overdue" in red) when `targetDate` is set; absent otherwise.
- Tap → `EditGoalSheet`. Swipe-to-delete.

**Frequency goal card**
- Title: "Workouts this week".
- Big number: `count / target`.
- Progress bar.
- Subtitle: "Resets Monday".
- Tap → `EditGoalSheet`. Swipe-to-delete.

**Bodyweight goal card**
- Title: "Bodyweight".
- Big number: current weight in lb, or "—" if no entries.
- Progress bar (cut vs bulk direction inferred from start/target).
- Subtitle: "Start X → Target Y lb".
- Inline trend chart: line of last 4 weeks of entries.
- Button: `Log weight` → `LogBodyweightSheet`.
- Tap card body (not the button) → `BodyweightDetailView`. Swipe-to-delete.

### Sheets

**`AddGoalSheet`** — kind picker at top (segmented control; kinds disabled if a singleton already active), then the kind-specific form:
- Lift: exercise row that taps into `AddExerciseView` (reused as picker), `targetE1RM` TextField (lb), optional `targetDate` toggle + `DatePicker`.
- Frequency: `workoutsPerWeek` Stepper, range 1–7.
- Bodyweight: `targetWeightLb` TextField, optional `targetDate`. If no prior `BodyweightEntry` exists, includes an inline "Log current weight" TextField that creates the first entry on save (so `startWeightLb` is non-zero). Sheet disables "Create Goal" until `target != start`.

**`EditGoalSheet`** — same form as Add but pre-populated. Only target value and `targetDate` editable; kind and (for lift) `exerciseId` locked. Delete button at bottom.

**`LogBodyweightSheet`** — weight TextField (lb), `DatePicker` defaulting to now, "Save" button. Posts `bodyweightEntrySavedNotification` on success.

### `BodyweightDetailView` (push from card tap)

- Full-size line chart of all `BodyweightEntry` rows over time (reuses the SwiftUI `Charts` import the e1RM chart uses).
- Entry list below: date + weight, swipe-to-delete.
- `Log weight` button at top opens the same `LogBodyweightSheet`.
- Toolbar trailing item: `Edit Goal` → opens `EditGoalSheet` for the bodyweight goal. This is the only edit/delete path for the bodyweight goal (the card itself only swipes to delete and taps to push the detail).

### ViewModel injection

`GoalsViewModel` is created as `@StateObject` on `RootTabView`. Both `StatsViewModel` and `GoalsViewModel` are injected via `@EnvironmentObject` so `GoalsView` can read `StatsViewModel.sessions` without a second listener.

## Edge cases

- **Deleted exercise behind a lift goal:** `exerciseName` is denormalized so the card still renders. Progress stops advancing because no future `LoggedSet` will carry the dead `exerciseId`. User can delete or recreate.
- **Bodyweight goal with no entries yet:** card shows current "—", percent 0. `Log weight` CTA stays prominent. Goal still editable/deletable.
- **`start == target` on bodyweight:** validated at create — sheet disables "Create Goal".
- **Direction inversion (bulk goal, user loses weight):** percent clamps to `[0, 1]`. No negative display.
- **Frequency week boundary:** `Calendar.current.firstWeekday = 2` (Monday). Long-distance travel can shift the bucket — same model as the Stats Current Streak.
- **Deadline passes without hit:** "Due in N days" pill flips to red "Overdue". No auto-fail or auto-delete — user decides.
- **Auto-completion idempotency:** `markCompleted` no-ops if `status == .completed`. Save → reload → eval cycle is safe to repeat.
- **Reload loop:** `markCompleted(silent: true)` suppresses `goalSavedNotification` to break the auto-complete → reload chain.
- **Session deletion:** no delete-session UI exists in v1, so no `sessionDeletedNotification` today. Documented as a follow-up if session delete ever lands.
- **Editing a completed goal:** locked — only delete available. `EditGoalSheet` checks `status` on open.
- **Singleton race:** UI hides "Add" when an active singleton exists; `createGoal` throws `singletonKindExists` if a write still races through. Sheet surfaces this as an alert.

## Error handling

- All `GoalsManager` errors propagate to `GoalsViewModel.errorMessage` (mirrors `StatsViewModel.errorMessage`). View renders an inline `Alert`.
- Validation errors (negative or zero target, invalid weight, `start == target`) caught client-side in the sheet, never reach Firestore.

## Testing

- `GoalsMathTests` (new file under `fitnessAppTests/`): pure-function tests for `liftProgress`, `frequencyProgress`, `bodyweightProgress` covering empty data, exact hit, over target, mixed exercises (lift), week boundary (frequency), bulk vs cut direction (bodyweight), zero-clamp. No Firestore.
- Manual sim verification end-to-end: create each kind, log a session that crosses a lift target, watch auto-complete, log a weight, watch progress + chart, edit a goal, delete one, expand the completed-section disclosure.
- No new `GoalsManager` tests — Firestore is hard to mock and existing managers in this repo are test-free. Following the pattern.

## Out of scope (v1)

- Body fat % or measurement tracking.
- Per-lift goals expressed as literal weight×reps (only e1RM in v1).
- Monthly frequency goals.
- Goal templates / suggested goals.
- Notifications or session-save toasts when a goal is hit.
- Surfacing Active Goals on the Stats tab.
- Goal sharing or social comparison (deferred to M6 Friends).

## Open follow-ups

- If session deletion is ever added, post a `sessionDeletedNotification` from `WorkoutSessionManager` so `GoalsViewModel` can re-evaluate completions (a deleted PR session might "un-complete" a goal — design TBD then).
- `formatWeight` duplication noted in the roadmap memory still applies; the Goals card will introduce a fifth caller. Worth extracting to a shared formatter when this lands.

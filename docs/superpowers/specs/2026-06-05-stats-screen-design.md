# Stats Screen — Design (Group 6)

Date: 2026-06-05
Status: approved
Predecessors: `2026-05-31-barbellbase-audit.md`, `2026-05-31-data-layer-design.md`, `2026-06-03-active-workout-session-design.md`

## Goal

Replace the `ComingSoonContent` placeholder on the Stats tab with a real dashboard powered by completed `WorkoutSession` data. Surface four metric families on day one — workouts + streak, volume over time, per-exercise PRs, and category split — plus a per-exercise drill-down. No new persistence; everything is computed client-side from sessions already saved by Group 5.

## Scoping decisions (locked in during brainstorming)

| Decision | Choice |
|---|---|
| Metrics in v1 | Total workouts + streak, volume chart, per-exercise PRs, body-part category split — all four. |
| Volume chart window | Toggle: 4w (per-session bars) / 12w (per-week bars) / All-time (per-month bars). |
| PR definition | Both heaviest weight AND best estimated 1RM (Epley), shown side by side on each row. |
| Streak rule | Consecutive weeks (Mon–Sun) with ≥1 completed session. |
| Drill-down | Yes — tapping a PR row opens an `ExerciseDetailView` with e1RM-over-time chart + session history. |
| Data flow | Fetch all completed sessions once, compute everything in Swift, cache in a long-lived VM, invalidate via `NotificationCenter` when a new session is saved. |
| Category split window | Follows the same `selectedWindow` toggle as the volume chart. |

## Architecture

`StatsViewModel` is an `@MainActor` `ObservableObject` owned by `RootTabView` and injected into `StatsView` (and onward to `ExerciseDetailView`) via `@EnvironmentObject`. Owning it at the tab root keeps the cached `sessions` array alive across tab switches; without that, swiping away and back would force a refetch every time.

The VM holds the raw session list and exposes derived metrics as computed properties — never stored, always pure functions of `(sessions, selectedWindow)`. There's no separate "stats" Firestore document; we're trading one fetch on first load for never having to worry about aggregate drift.

`WorkoutSessionManager` grows two things: a `listAllCompletedSessions(userId:)` query (same as `listRecentSessions` minus the `.limit`) and a `sessionSavedNotification` that `saveCompletedSession` posts on success. The VM subscribes on init and flips an internal `needsRefresh` flag; the next `.onAppear` triggers a refetch. Tab switches with no new session do nothing.

## Data model

No new Firestore types and no schema changes. Two in-memory helper types live next to `StatsViewModel`:

```swift
struct VolumeBin: Identifiable {
    let id = UUID()
    let label: String     // "Jun 1" / "May 25" / "Jun 26"
    let date: Date        // bin anchor — session date, week-start Monday, or month-start
    let volume: Double
}

struct ExercisePRRow: Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let exerciseName: String
    let heaviestWeight: Double          // best actualWeight across completed sets > 0
    let heaviestWeightReps: Int         // reps on the set that achieved heaviestWeight
    let bestEstimated1RM: Double        // best Epley e1RM across completed sets
}

enum TimeWindow: String, CaseIterable, Identifiable {
    case fourWeeks, twelveWeeks, allTime
    var id: String { rawValue }
    var label: String { ... }           // "4w" / "12w" / "All"
}
```

## Manager API

Additions to `fitnessApp/Firestore/WorkoutSessionManager.swift`:

```swift
extension WorkoutSessionManager {
    static let sessionSavedNotification = Notification.Name("WorkoutSessionSaved")

    func listAllCompletedSessions(userId: String) async throws -> [WorkoutSession]
}
```

`listAllCompletedSessions` runs the same query as `listRecentSessions` — `users/{uid}/sessions` where `completed_at != nil`, ordered by `completed_at` desc — with no `.limit`. `saveCompletedSession` is modified to post `sessionSavedNotification` after a successful write (no payload needed; the VM just refetches).

The existing `listRecentSessions(userId:, limit:)` is unchanged and stays the source for the Workout tab's Recent Workouts row.

## `StatsViewModel`

```swift
@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedWindow: TimeWindow = .twelveWeeks

    private var needsRefresh: Bool = true
    private var sessionSavedObserver: NSObjectProtocol?

    init() { /* subscribe to sessionSavedNotification → needsRefresh = true */ }
    deinit { /* remove observer */ }

    func loadIfNeeded(userId: String) async    // call from StatsView.onAppear
    func refresh(userId: String) async          // pull-to-refresh; forces fetch
    func reset()                                // sign-out: sessions = [], needsRefresh = true
}
```

Computed properties on the VM (all pure functions of `sessions` filtered to `completedAt != nil`, and where relevant `selectedWindow`):

- `totalWorkouts: Int` — `sessions.count`
- `currentStreakWeeks: Int`, `longestStreakWeeks: Int`
- `volumeSeries: [VolumeBin]`
- `windowTotalVolume: Double`, `windowSessionCount: Int` (for the subtitle line)
- `prRows: [ExercisePRRow]` — sorted by `bestEstimated1RM` desc
- `categorySplit: [(ExerciseCategory, Double)]` — sorted by volume desc, zero categories dropped

### Metric formulas

**Volume per set:** `Double(actualReps) × (actualWeight ?? 0)`, only when `isCompleted == true`. Bodyweight / no-weight sets contribute 0 — explicit v1 limitation.

**Streak weeks:** anchor on Mon–Sun using `Calendar.current` with `firstWeekday = 2`. Build the set of week-start dates that contain ≥1 completed session. `currentStreakWeeks` walks backwards from this week's Monday while each week is in the set. `longestStreakWeeks` scans the sorted week-starts and tracks the max consecutive run by checking `Calendar.dateComponents([.weekOfYear], from: a, to: b).weekOfYear == 1`.

**Volume series** by window:
- `.fourWeeks`: one bin per completed session in the last 28 days; label = `M/d` of `completedAt`
- `.twelveWeeks`: one bin per week-start in the last 12 weeks; weeks with no sessions render as 0; label = `M/d` of Monday
- `.allTime`: one bin per month from the earliest session forward; empty months render as 0; label = `MMM yy`

**PR rows:** group all completed sets across all sessions by `exerciseId`. For each group:
- `heaviestWeight` = `max(actualWeight)` across sets where `actualWeight > 0`; record the reps on the winning set
- `bestEstimated1RM` = `max(weight × (1 + Double(reps)/30.0))` (Epley)
- Exercises with no weighted sets are excluded entirely (they have no meaningful PR)

`exerciseName` is taken from the most recent `LoggedExercise` in the group so a rename in the catalog is reflected without us tracking history.

**Category split:** for each completed set, resolve `exerciseId` against `ExerciseCatalog.shared`. Unknown id (deleted custom, missing catalog entry) → `.other`. Sum volume per category, filter to non-zero, sort desc, render as percentages of the window total.

## UI

### `StatsView`

Replaces `fitnessApp/Placeholders/StatsView.swift` — the file moves to `fitnessApp/StatsView.swift` and `Placeholders/` keeps only `FriendsView` and `GoalsView`. `NavigationStack` root with the same dark navy `#081f3a` background and `toolbarBackground(.visible, for: .navigationBar)` / `toolbarColorScheme(.dark, for: .navigationBar)` treatment used in the other tabs. Navigation title "Stats".

Body is a `ScrollView` with `.refreshable { await vm.refresh(userId: uid) }`. Top-to-bottom sections, ~16pt vertical padding between:

**1. Header tile row** — two compact tiles side by side:
- `Total Workouts` — big number + small label
- `Current Streak` — big number + "weeks" label + secondary line "Longest: N"

**2. Volume chart card**
- Title row: "Volume" on the left, segmented `Picker("", selection: $vm.selectedWindow)` (4w · 12w · All) on the right
- SwiftUI `Charts` `BarMark(x: .value("Date", bin.label), y: .value("Volume", bin.volume))` — yellow accent bars on navy, faint horizontal gridlines, min height ~220pt
- Subtitle line below: "Total this window: 12,450 lbs · N sessions"
- Empty window: "No volume in this window" centered in the chart frame

**3. Personal Records card**
- Title "Personal Records"
- `LazyVStack` of `PRRowView`s. Each row:
  - Left: `exerciseName` (bold)
  - Right column, two stacked small labels: `Heaviest: 225 lbs × 3` and `Est. 1RM: 247 lbs`
  - Trailing chevron — the row is tappable
- Top 10 by default with a "Show all" disclosure that expands the rest
- Empty: "Log a workout to start tracking PRs."
- Tap → `NavigationLink` value `ExerciseDetailDestination(exerciseId:, exerciseName:)`

**4. Category split card**
- Title "Volume by Category"
- Horizontal 100%-wide stacked bar, segments proportional to each category's share of `windowTotalVolume`
- Legend below in two columns: colored swatch · category display name · `XX%`
- Filtered by the same `selectedWindow` toggle as the volume chart
- Hidden entirely when `windowTotalVolume == 0`

**5. Bottom safe-area spacing** so the tab bar doesn't clip the last card.

### `ExerciseDetailView`

New file `fitnessApp/ExerciseDetailView.swift`. Pushed via `.navigationDestination(for: ExerciseDetailDestination.self)` on the Stats `NavigationStack`. Initialized with `exerciseId`, `exerciseName`, and a reference to the shared `StatsViewModel` (so it reads sessions from the same in-memory list — no extra fetch). Same dark navy background, navigation title = `exerciseName`.

`ScrollView` body:

**1. PR tile row** — three small tiles: Heaviest, Best e1RM, Total Sessions (count of distinct sessions that contain this exercise across the full history).

**2. e1RM-over-time chart card**
- Same segmented window picker (4w / 12w / All) above the chart, owned locally on the detail view (independent of the Stats tab's picker)
- SwiftUI `Charts` line+point chart: x = `session.completedAt`, y = max e1RM across that session's sets for this exercise; yellow line on navy
- Empty window: "No sessions in this window" centered in the chart frame

**3. History list**
- Title "History"
- All sessions containing this exercise, sorted by `completedAt` desc (not filtered by window — full history)
- One card per session:
  - Header: formatted date (`Today` / `Yesterday` / `Jun 1`) + template name in muted text
  - Body: one line per completed set: `Set 1 — 12 × 135 lbs (e1RM 184)`
- Tap a session card → presents existing `SessionSummaryView(session:, mode: .readOnly)` as a `.sheet`

No write paths anywhere in this view.

## States

**Empty (zero completed sessions):** the entire `StatsView` body is replaced with a centered placeholder — chart icon, "No stats yet", subtitle "Finish your first workout to see your progress here." No tiles, no empty cards. Same treatment as `ComingSoonContent` but with the right copy.

**Loading (first load, `sessions.isEmpty && isLoading`):** centered `ProgressView()` on the navy background. Subsequent loads (cache exists, refresh in background) don't show a spinner.

**Error:** if `load`/`refresh` throws, set `errorMessage`. Render an inline banner at the top of the scroll view — "Couldn't load stats. Pull to refresh." — and keep showing whatever cached `sessions` we have. Pull-to-refresh retries.

## Edge cases

- **Bodyweight / no-weight sets** — `actualWeight == nil || == 0` contributes 0 to volume and is excluded from PR computations. Documented v1 limitation.
- **Deleted catalog exercises** — PR row renders with the denormalized `exerciseName` from `LoggedExercise`; category split falls back to `.other`; detail view still works off the in-memory sessions.
- **Time zones / DST** — week math uses `Calendar.current` with `firstWeekday = 2`; `dateComponents([.weekOfYear], from:to:)` handles DST correctly.
- **Sessions with `completedAt == nil`** — filtered out defensively; saved sessions should always have it set.
- **Sign-out** — `RootTabView`'s auth observer calls `statsVM.reset()` so a new user doesn't see the previous user's stats.
- **Cache invalidation race** — if the notification fires while the Stats tab is on-screen, `needsRefresh` is set but no fetch happens until the next `.onAppear`. Acceptable; the user will see the new session next time they revisit the tab.
- **Charts framework availability** — requires iOS 16+. Project already targets iOS 17, no gate needed.
- **Double-fetch on first appear** — `loadIfNeeded` is the single entry point and gates on `sessions.isEmpty || needsRefresh`, so a second `.onAppear` while loading is a no-op.

## What this fixes

- Audit item M4 — Stats tab is now a real feature instead of `ComingSoonContent`.

## What this does NOT address (acceptable for v1)

- Goals tab (M5) — separate design.
- Friends tab (M6) — separate design.
- Bodyweight-exercise volume accounting (no concept of bodyweight in the data model yet).
- PR notifications / celebrations when a new PR is set during a session.
- Sharing or exporting stats.
- Stats for a friend (depends on M6).
- Per-week or per-month volume targets / progress against a goal (depends on M5).
- Cleaning up stale `Schedule` references to deleted templates (existing known debt, unchanged).
- Refactoring duplicated `formatWeight` into a `Double` extension (known debt, touch when next editing those files).

## Files touched

**New:**
- `fitnessApp/StatsView.swift` (replaces the `Placeholders/` version; includes `StatsViewModel`, `VolumeBin`, `ExercisePRRow`, `TimeWindow`, `ExerciseDetailDestination`)
- `fitnessApp/ExerciseDetailView.swift`

**Modified:**
- `fitnessApp/Placeholders/StatsView.swift` — deleted (moved to `fitnessApp/StatsView.swift`)
- `fitnessApp/Firestore/WorkoutSessionManager.swift` — add `listAllCompletedSessions(userId:)` and `sessionSavedNotification`; post notification from `saveCompletedSession`
- `fitnessApp/RootTabView.swift` — own a `StatsViewModel` instance, inject as `@EnvironmentObject`, and call `statsVM.reset()` on sign-out

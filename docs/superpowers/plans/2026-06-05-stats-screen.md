# Stats Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `ComingSoonContent` placeholder on the Stats tab with a real dashboard powered by completed `WorkoutSession` data: total workouts + streak tiles, volume-over-time chart (4w / 12w / All), per-exercise PR list with drill-down, and category split. No new persistence — everything is computed client-side from the sessions Group 5 already saves.

**Architecture:** A `StatsViewModel` owned by `RootTabView` as a `@StateObject` and injected to `StatsView` (and `ExerciseDetailView`) via `@EnvironmentObject`. The VM caches the full session list in memory and invalidates via a `NotificationCenter` post fired from `WorkoutSessionManager.saveCompletedSession`. All metrics (`totalWorkouts`, `currentStreakWeeks`, `volumeSeries`, `prRows`, `categorySplit`) are computed properties — pure functions of `(sessions, selectedWindow)` with no stored derived state. Charts use Apple's `SwiftUI Charts` framework. Per-exercise drill-down pushes onto the Stats `NavigationStack` and reads from the same in-memory session list — no extra fetch.

**Tech Stack:** SwiftUI, SwiftUI `Charts` (iOS 16+), Swift Concurrency (`async/await`, `Task`), Firebase Firestore, the project's existing snake_case CodingKeys + singleton manager + `@MainActor ObservableObject` patterns.

**Testing note:** Per project preference (Defer tests, chosen at Group 3 and continued through Group 5), this plan uses build-verify + manual smoke test instead of unit tests. Each task ends with `xcodebuild` verification, an explicit manual smoke test, and a commit.

**Spec:** `docs/superpowers/specs/2026-06-05-stats-screen-design.md`

---

## File Structure

**New files:**
- `fitnessApp/StatsView.swift` — view + `StatsViewModel` + helper types (`TimeWindow`, `VolumeBin`, `ExercisePRRow`, `ExerciseDetailDestination`)
- `fitnessApp/ExerciseDetailView.swift` — per-exercise drill-down

**Deleted files:**
- `fitnessApp/Placeholders/StatsView.swift` — replaced by the new top-level `StatsView.swift`

**Modified files:**
- `fitnessApp/Firestore/WorkoutSessionManager.swift` — add `listAllCompletedSessions(userId:)` and `sessionSavedNotification`; post the notification from `saveCompletedSession`
- `fitnessApp/RootTabView.swift` — own a `StatsViewModel` via `@StateObject` and inject as `@EnvironmentObject`

---

## Reusable build command

Throughout this plan, "build the app" means running this from the repo root:

```bash
xcodebuild \
  -project fitnessApp.xcodeproj \
  -scheme fitnessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | tail -40
```

Expected: `BUILD SUCCEEDED` at the end. New `.swift` files under `fitnessApp/` auto-register via Xcode 16 synced groups — no `project.pbxproj` edits needed. SourceKit "Cannot find X in scope" warnings in the IDE are noise; trust the `xcodebuild` result.

---

### Task 1: Manager extensions — fetch-all + saved notification

Add the API the VM needs and the invalidation hook that keeps the cache fresh.

**Files:**
- Modify: `fitnessApp/Firestore/WorkoutSessionManager.swift`

- [ ] **Step 1: Add `sessionSavedNotification` static and post it from `saveCompletedSession`**

Replace the existing `saveCompletedSession` body and add a notification name. After the edit, the top of the class and the `saveCompletedSession` function should look like this:

```swift
final class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
    static let sessionSavedNotification = Notification.Name("WorkoutSessionSaved")
    private init() {}

    private func sessionsCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("sessions")
    }

    private func sessionDocument(userId: String, sessionId: String) -> DocumentReference {
        sessionsCollection(userId: userId).document(sessionId)
    }

    func saveCompletedSession(_ session: WorkoutSession) async throws {
        try sessionDocument(userId: session.userId, sessionId: session.id)
            .setData(from: session, merge: false)
        NotificationCenter.default.post(name: Self.sessionSavedNotification, object: nil)
    }
    // ... rest of the file unchanged
}
```

- [ ] **Step 2: Add `listAllCompletedSessions(userId:)`**

Append this method to the class, right after `listRecentSessions`:

```swift
    func listAllCompletedSessions(userId: String) async throws -> [WorkoutSession] {
        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: WorkoutSession.CodingKeys.completedAt.rawValue, descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutSession.self) }
    }
```

- [ ] **Step 3: Build the app**

Run the reusable build command. Expected: `BUILD SUCCEEDED`. No new compile errors in `WorkoutSessionManager.swift`.

- [ ] **Step 4: Commit**

```bash
git add fitnessApp/Firestore/WorkoutSessionManager.swift
git commit -m "Add listAllCompletedSessions + sessionSavedNotification (Group 6)"
```

---

### Task 2: StatsView shell + VM (data fetch, caching, states) + wire into RootTabView

Replace the placeholder with a real `StatsView` that fetches sessions, caches them, and renders empty / loading / error / "loaded but no UI yet" states. No metrics yet — those land in Tasks 3–6.

**Files:**
- Create: `fitnessApp/StatsView.swift`
- Delete: `fitnessApp/Placeholders/StatsView.swift`
- Modify: `fitnessApp/RootTabView.swift`

- [ ] **Step 1: Delete the placeholder**

```bash
git rm fitnessApp/Placeholders/StatsView.swift
```

- [ ] **Step 2: Create `fitnessApp/StatsView.swift`**

```swift
//
//  StatsView.swift
//  fitnessApp
//

import SwiftUI

// MARK: - Helper types

enum TimeWindow: String, CaseIterable, Identifiable {
    case fourWeeks
    case twelveWeeks
    case allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fourWeeks:   return "4w"
        case .twelveWeeks: return "12w"
        case .allTime:     return "All"
        }
    }
}

// MARK: - StatsViewModel

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedWindow: TimeWindow = .twelveWeeks

    private var needsRefresh: Bool = true
    private var sessionSavedObserver: NSObjectProtocol?

    init() {
        sessionSavedObserver = NotificationCenter.default.addObserver(
            forName: WorkoutSessionManager.sessionSavedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `queue: .main` guarantees the calling thread, but MainActor
            // isolation isn't inferred — hop explicitly.
            Task { @MainActor [weak self] in
                self?.needsRefresh = true
            }
        }
    }

    deinit {
        if let observer = sessionSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private var userId: String? {
        (try? AuthenticationManager.shared.getAuthenticatedUser())?.uid
    }

    func loadIfNeeded() async {
        guard let uid = userId else { return }
        guard sessions.isEmpty || needsRefresh else { return }
        await fetch(userId: uid)
    }

    func refresh() async {
        guard let uid = userId else { return }
        await fetch(userId: uid)
    }

    private func fetch(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await WorkoutSessionManager.shared
                .listAllCompletedSessions(userId: userId)
                .filter { $0.completedAt != nil }
            self.sessions = loaded
            self.needsRefresh = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load stats. Pull to refresh."
        }
    }
}

// MARK: - StatsView

struct StatsView: View {
    @EnvironmentObject private var vm: StatsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                content
            }
            .navigationTitle("Stats")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await vm.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.sessions.isEmpty && vm.isLoading {
            ProgressView().tint(.yellow)
        } else if vm.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    // Tiles + cards land in Tasks 3–6
                    Text("Loaded \(vm.sessions.count) sessions")
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                }
                .padding(.bottom, 32)
            }
            .refreshable { await vm.refresh() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow.opacity(0.8))
            Text("No stats yet")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Finish your first workout to see your progress here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.4))
            .cornerRadius(8)
            .padding(.horizontal)
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsViewModel())
}
```

- [ ] **Step 3: Wire `StatsViewModel` into `RootTabView`**

Replace `fitnessApp/RootTabView.swift` with:

```swift
//
//  RootTabView.swift
//  fitnessApp
//

import SwiftUI

struct RootTabView: View {
    @Binding var showSignInView: Bool
    @StateObject private var statsViewModel = StatsViewModel()

    init(showSignInView: Binding<Bool> = .constant(false)) {
        self._showSignInView = showSignInView
    }

    var body: some View {
        TabView {
            StatsView()
                .environmentObject(statsViewModel)
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "bolt.circle") }

            NavigationStack {
                ProfileView(showSignInView: $showSignInView)
            }
            .tabItem { Label("Profile", systemImage: "person") }

            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
        }
        .tint(.yellow)
        .toolbarBackground(Color(hex: "#06152a"), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    RootTabView()
}
```

- [ ] **Step 4: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke test**

Launch the app in the simulator. Sign in. Open the Stats tab.

Expected behavior:
- **If the user has zero completed sessions:** the empty-state placeholder ("No stats yet" + chart icon + subtitle) is centered.
- **If the user has ≥1 session:** a "Loaded N sessions" debug line shows in the scroll view, plus pull-to-refresh works.

If you have no sessions on the test account, complete a quick session via the Workout tab first.

- [ ] **Step 6: Commit**

```bash
git add fitnessApp/StatsView.swift fitnessApp/RootTabView.swift fitnessApp/Placeholders/StatsView.swift
git commit -m "Add StatsView shell + StatsViewModel with caching (Group 6)"
```

---

### Task 3: Header tile row — Total Workouts + Streak

Replace the "Loaded N sessions" debug line with the real header: two tiles (Total Workouts, Current Streak with "Longest: N" subtitle).

**Files:**
- Modify: `fitnessApp/StatsView.swift`

- [ ] **Step 1: Add streak + totals computations to `StatsViewModel`**

Append these inside the `StatsViewModel` class (above `init()` is fine, but anywhere in the class works):

```swift
    var totalWorkouts: Int { sessions.count }

    private var weekStartsWithSession: Set<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        var starts: Set<Date> = []
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: completed
            )
            if let weekStart = calendar.date(from: components) {
                starts.insert(weekStart)
            }
        }
        return starts
    }

    var currentStreakWeeks: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let starts = weekStartsWithSession
        guard !starts.isEmpty else { return 0 }
        let today = Date()
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: today
        )
        guard var cursor = calendar.date(from: components) else { return 0 }
        var streak = 0
        while starts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }

    var longestStreakWeeks: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let sorted = weekStartsWithSession.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<sorted.count {
            let diff = calendar.dateComponents(
                [.weekOfYear],
                from: sorted[index - 1],
                to: sorted[index]
            ).weekOfYear ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
```

- [ ] **Step 2: Add the header tile row to `StatsView`**

Replace the debug `Text("Loaded \(vm.sessions.count) sessions")` line inside the `ScrollView` `VStack` with a call to `headerTiles`, and add the `headerTiles` view + `statTile` helper. The relevant `content` and helpers should now look like:

```swift
    @ViewBuilder
    private var content: some View {
        if vm.sessions.isEmpty && vm.isLoading {
            ProgressView().tint(.yellow)
        } else if vm.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerTiles
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .refreshable { await vm.refresh() }
        }
    }

    private var headerTiles: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Total Workouts",
                value: "\(vm.totalWorkouts)",
                subtitle: nil
            )
            statTile(
                title: "Current Streak",
                value: "\(vm.currentStreakWeeks)",
                subtitle: "weeks · longest \(vm.longestStreakWeeks)"
            )
        }
    }

    private func statTile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(.yellow)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }
```

- [ ] **Step 3: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test**

Launch the simulator. Open Stats. With ≥1 completed session, you should see:
- "Total Workouts: N" tile on the left
- "Current Streak: N weeks · longest M" tile on the right
- Both tiles styled in the project's yellow-on-navy idiom

Quick streak sanity check: if you have a session this week and one last week, `Current Streak` should read `2`. If only this week, `1`. With no completed sessions, the empty state still renders (no tiles).

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/StatsView.swift
git commit -m "Add Stats header tiles: total workouts + streak (Group 6)"
```

---

### Task 4: Volume chart card with 4w / 12w / All-time toggle

Add the volume bar chart with the segmented window picker. This is the biggest task.

**Files:**
- Modify: `fitnessApp/StatsView.swift`

- [ ] **Step 1: Add `VolumeBin` type and helpers to the top of `StatsView.swift`**

Just below the `TimeWindow` enum (above `StatsViewModel`), add:

```swift
struct VolumeBin: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let volume: Double
}

private enum StatsMath {
    static func volume(of session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { exerciseSum, exercise in
            exerciseSum + exercise.sets.reduce(0) { setSum, set in
                guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                    return setSum
                }
                return setSum + Double(set.actualReps) * weight
            }
        }
    }

    static func mondayCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}
```

- [ ] **Step 2: Add `volumeSeries`, `windowTotalVolume`, `windowSessionCount` to `StatsViewModel`**

Append inside the `StatsViewModel` class:

```swift
    private var sessionsInWindow: [WorkoutSession] {
        let calendar = StatsMath.mondayCalendar()
        switch selectedWindow {
        case .fourWeeks:
            guard let cutoff = calendar.date(byAdding: .day, value: -28, to: Date()) else {
                return sessions
            }
            return sessions.filter { ($0.completedAt ?? .distantPast) >= cutoff }
        case .twelveWeeks:
            guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -12, to: Date()) else {
                return sessions
            }
            return sessions.filter { ($0.completedAt ?? .distantPast) >= cutoff }
        case .allTime:
            return sessions
        }
    }

    var windowSessionCount: Int { sessionsInWindow.count }

    var windowTotalVolume: Double {
        sessionsInWindow.reduce(0) { $0 + StatsMath.volume(of: $1) }
    }

    var volumeSeries: [VolumeBin] {
        let calendar = StatsMath.mondayCalendar()
        switch selectedWindow {
        case .fourWeeks:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return sessionsInWindow
                .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
                .compactMap { session in
                    guard let date = session.completedAt else { return nil }
                    return VolumeBin(
                        label: formatter.string(from: date),
                        date: date,
                        volume: StatsMath.volume(of: session)
                    )
                }
        case .twelveWeeks:
            return weeklyBins(weeks: 12, calendar: calendar)
        case .allTime:
            return monthlyBins(calendar: calendar)
        }
    }

    private func weeklyBins(weeks: Int, calendar: Calendar) -> [VolumeBin] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let today = Date()
        guard let thisWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return [] }

        var bins: [(weekStart: Date, volume: Double)] = []
        for offset in (0..<weeks).reversed() {
            if let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) {
                bins.append((start, 0))
            }
        }
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: completed
            )
            guard let weekStart = calendar.date(from: components) else { continue }
            if let index = bins.firstIndex(where: { $0.weekStart == weekStart }) {
                bins[index].volume += StatsMath.volume(of: session)
            }
        }
        return bins.map {
            VolumeBin(label: formatter.string(from: $0.weekStart), date: $0.weekStart, volume: $0.volume)
        }
    }

    private func monthlyBins(calendar: Calendar) -> [VolumeBin] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        guard let earliest = sessions.compactMap(\.completedAt).min() else { return [] }
        let today = Date()
        guard
            let startMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: earliest)
            ),
            let endMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: today)
            )
        else { return [] }

        var bins: [(monthStart: Date, volume: Double)] = []
        var cursor = startMonth
        while cursor <= endMonth {
            bins.append((cursor, 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: completed)
            )
            guard let monthStart else { continue }
            if let index = bins.firstIndex(where: { $0.monthStart == monthStart }) {
                bins[index].volume += StatsMath.volume(of: session)
            }
        }
        return bins.map {
            VolumeBin(label: formatter.string(from: $0.monthStart), date: $0.monthStart, volume: $0.volume)
        }
    }
```

- [ ] **Step 3: Add `import Charts` at the top of `StatsView.swift`**

Right after `import SwiftUI`, add:

```swift
import Charts
```

- [ ] **Step 4: Add the volume chart card to `StatsView`**

Update the `ScrollView` `VStack` in `content` so that `headerTiles` is followed by `volumeCard`:

```swift
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerTiles
                        .padding(.horizontal)
                    volumeCard
                        .padding(.horizontal)
                }
```

Then add `volumeCard` and a tiny `formatVolume` helper to the view:

```swift
    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volume")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Picker("Window", selection: $vm.selectedWindow) {
                    ForEach(TimeWindow.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if vm.volumeSeries.allSatisfy({ $0.volume == 0 }) {
                Text("No volume in this window")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(vm.volumeSeries) { bin in
                    BarMark(
                        x: .value("Date", bin.label),
                        y: .value("Volume", bin.volume)
                    )
                    .foregroundStyle(Color.yellow)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }

            Text("Total this window: \(formatVolume(vm.windowTotalVolume)) lbs · \(vm.windowSessionCount) session\(vm.windowSessionCount == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private func formatVolume(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
```

- [ ] **Step 5: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`. If `Charts` fails to resolve, confirm the project's deployment target is iOS 16+ (it already is — the project uses iOS 17 features like `NavigationStack` everywhere).

- [ ] **Step 6: Manual smoke test**

Launch the simulator. Open Stats with ≥1 completed session.

Expected:
- "Volume" title with segmented picker on the right (4w / 12w / All) — defaults to 12w
- Bar chart in yellow on navy
- Subtitle below: "Total this window: X,XXX lbs · N sessions"
- Tap each window option — the chart re-renders with the right time aggregation. 4w shows one bar per session; 12w shows one bar per week (including 0-bars for empty weeks); All shows one bar per month.
- A window with no sessions shows "No volume in this window" centered in the chart area instead of the chart.

- [ ] **Step 7: Commit**

```bash
git add fitnessApp/StatsView.swift
git commit -m "Add Stats volume chart with 4w / 12w / all-time toggle (Group 6)"
```

---

### Task 5: Personal Records card with top-10 + "Show all"

Add the PR list. Tapping a row is a no-op for this task; the navigation destination lands in Task 7.

**Files:**
- Modify: `fitnessApp/StatsView.swift`

- [ ] **Step 1: Add `ExercisePRRow` + `ExerciseDetailDestination` types**

Just below `VolumeBin` (above `StatsMath`), add:

```swift
struct ExercisePRRow: Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let exerciseName: String
    let heaviestWeight: Double
    let heaviestWeightReps: Int
    let bestEstimated1RM: Double
}

struct ExerciseDetailDestination: Hashable {
    let exerciseId: String
    let exerciseName: String
}
```

Extend `StatsMath` with the Epley helper:

```swift
    static func epleyOneRepMax(weight: Double, reps: Int) -> Double {
        weight * (1.0 + Double(reps) / 30.0)
    }
```

- [ ] **Step 2: Add `prRows` computed property to `StatsViewModel`**

Append inside the class:

```swift
    var prRows: [ExercisePRRow] {
        struct Aggregate {
            var exerciseName: String
            var heaviestWeight: Double = 0
            var heaviestWeightReps: Int = 0
            var bestE1RM: Double = 0
        }

        var byExercise: [String: Aggregate] = [:]
        for session in sessions {
            for exercise in session.exercises {
                for set in exercise.sets {
                    guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                        continue
                    }
                    let e1rm = StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
                    var agg = byExercise[exercise.exerciseId]
                        ?? Aggregate(exerciseName: exercise.exerciseName)
                    agg.exerciseName = exercise.exerciseName // keep latest name
                    if weight > agg.heaviestWeight {
                        agg.heaviestWeight = weight
                        agg.heaviestWeightReps = set.actualReps
                    }
                    if e1rm > agg.bestE1RM {
                        agg.bestE1RM = e1rm
                    }
                    byExercise[exercise.exerciseId] = agg
                }
            }
        }

        return byExercise
            .map { id, agg in
                ExercisePRRow(
                    exerciseId: id,
                    exerciseName: agg.exerciseName,
                    heaviestWeight: agg.heaviestWeight,
                    heaviestWeightReps: agg.heaviestWeightReps,
                    bestEstimated1RM: agg.bestE1RM
                )
            }
            .sorted { $0.bestEstimated1RM > $1.bestEstimated1RM }
    }
```

- [ ] **Step 3: Add the PR card to `StatsView`**

Add `@State private var showAllPRs: Bool = false` near the top of `StatsView`:

```swift
struct StatsView: View {
    @EnvironmentObject private var vm: StatsViewModel
    @State private var showAllPRs: Bool = false
```

Update the `ScrollView` `VStack` in `content` to add `prCard` after `volumeCard`:

```swift
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerTiles
                        .padding(.horizontal)
                    volumeCard
                        .padding(.horizontal)
                    prCard
                        .padding(.horizontal)
                }
```

Then add:

```swift
    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)
                .foregroundColor(.white)

            if vm.prRows.isEmpty {
                Text("Log a workout to start tracking PRs.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                let rows = showAllPRs ? vm.prRows : Array(vm.prRows.prefix(10))
                LazyVStack(spacing: 8) {
                    ForEach(rows) { row in
                        NavigationLink(value: ExerciseDetailDestination(
                            exerciseId: row.exerciseId,
                            exerciseName: row.exerciseName
                        )) {
                            prRowView(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if vm.prRows.count > 10 {
                    Button(showAllPRs ? "Show less" : "Show all (\(vm.prRows.count))") {
                        withAnimation { showAllPRs.toggle() }
                    }
                    .font(.footnote)
                    .foregroundColor(.yellow)
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private func prRowView(_ row: ExercisePRRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(row.exerciseName)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Heaviest: \(formatVolume(row.heaviestWeight)) lbs × \(row.heaviestWeightReps)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                Text("Est. 1RM: \(formatVolume(row.bestEstimated1RM)) lbs")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
```

- [ ] **Step 4: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`. (The `NavigationLink(value:)` will compile without a matching `.navigationDestination` — tapping just won't do anything yet. Task 7 wires it up.)

- [ ] **Step 5: Manual smoke test**

Launch the simulator. Open Stats with ≥1 completed session that contains weighted sets.

Expected:
- "Personal Records" title
- Up to 10 rows, each showing exercise name on the left and two right-aligned labels: `Heaviest: 225 lbs × 3` and `Est. 1RM: 247 lbs`
- Rows are sorted by estimated 1RM desc
- A right chevron on every row (tap is a no-op for now)
- If you have >10 distinct exercises with weighted sets, a "Show all (N)" button appears below; tapping toggles between top-10 and all

Sessions with no weighted sets (e.g., cardio-only) don't contribute rows.

- [ ] **Step 6: Commit**

```bash
git add fitnessApp/StatsView.swift
git commit -m "Add Stats Personal Records card with top-10 + show all (Group 6)"
```

---

### Task 6: Category split card

Add the body-part stacked bar driven by the catalog category lookup. Follows the same `selectedWindow` toggle as the volume chart.

**Files:**
- Modify: `fitnessApp/StatsView.swift`

- [ ] **Step 1: Add `categorySplit` computed property to `StatsViewModel`**

Append inside the class:

```swift
    var categorySplit: [(category: ExerciseCategory, volume: Double)] {
        let catalog = ExerciseCatalog.shared.all
        let lookup: [String: ExerciseCategory] = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.id, $0.category) }
        )

        var totals: [ExerciseCategory: Double] = [:]
        for session in sessionsInWindow {
            for exercise in session.exercises {
                let category = lookup[exercise.exerciseId] ?? .other
                let exerciseVolume = exercise.sets.reduce(0.0) { sum, set in
                    guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                        return sum
                    }
                    return sum + Double(set.actualReps) * weight
                }
                if exerciseVolume > 0 {
                    totals[category, default: 0] += exerciseVolume
                }
            }
        }

        return totals
            .filter { $0.value > 0 }
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }
```

- [ ] **Step 2: Add a category color helper to `StatsView.swift` (file scope, above `StatsView`)**

```swift
private extension ExerciseCategory {
    var color: Color {
        switch self {
        case .chest:     return Color.red
        case .back:      return Color.blue
        case .shoulders: return Color.orange
        case .arms:      return Color.purple
        case .legs:      return Color.green
        case .core:      return Color.pink
        case .cardio:    return Color.teal
        case .other:     return Color.gray
        }
    }
}
```

- [ ] **Step 3: Add the category card to `StatsView`**

Update the `ScrollView` `VStack` in `content` to add `categoryCard` after `prCard`:

```swift
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerTiles
                        .padding(.horizontal)
                    volumeCard
                        .padding(.horizontal)
                    prCard
                        .padding(.horizontal)
                    if !vm.categorySplit.isEmpty {
                        categoryCard
                            .padding(.horizontal)
                    }
                }
```

Then add `categoryCard`:

```swift
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume by Category")
                .font(.headline)
                .foregroundColor(.white)

            let total = vm.categorySplit.reduce(0) { $0 + $1.volume }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(vm.categorySplit, id: \.category) { entry in
                        Rectangle()
                            .fill(entry.category.color)
                            .frame(width: geo.size.width * CGFloat(entry.volume / max(total, 1)))
                    }
                }
            }
            .frame(height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(vm.categorySplit, id: \.category) { entry in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.category.color)
                            .frame(width: 10, height: 10)
                        Text(entry.category.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text("\(Int((entry.volume / max(total, 1)) * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }
```

- [ ] **Step 4: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke test**

Launch the simulator. Open Stats with ≥1 completed session with weighted sets across at least two different exercise categories.

Expected:
- "Volume by Category" card below Personal Records
- A single horizontal bar split into colored segments proportional to each category's share of window volume
- Two-column legend below: colored swatch · category name · percentage
- Switching the volume picker (4w / 12w / All) also re-filters the category split
- When the current window has zero volume, the entire card is hidden

- [ ] **Step 6: Commit**

```bash
git add fitnessApp/StatsView.swift
git commit -m "Add Stats category split card (Group 6)"
```

---

### Task 7: `ExerciseDetailView` drill-down

Wire up the PR-row tap target: a new pushed view with PR tiles, an e1RM line chart with its own 4w/12w/All toggle, and a full-history list whose rows open the existing `SessionSummaryView` in `.readOnly` mode.

**Files:**
- Create: `fitnessApp/ExerciseDetailView.swift`
- Modify: `fitnessApp/StatsView.swift`

- [ ] **Step 1: Create `fitnessApp/ExerciseDetailView.swift`**

```swift
//
//  ExerciseDetailView.swift
//  fitnessApp
//

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseId: String
    let exerciseName: String

    @EnvironmentObject private var statsVM: StatsViewModel
    @State private var window: TimeWindow = .twelveWeeks
    @State private var selectedHistorySession: WorkoutSession?

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tilesRow
                        .padding(.horizontal)
                    chartCard
                        .padding(.horizontal)
                    historyCard
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedHistorySession) { session in
            SessionSummaryView(
                session: session,
                mode: .readOnly,
                onDismiss: { selectedHistorySession = nil }
            )
        }
    }

    // MARK: - Derived data

    private var sessionsContainingExercise: [WorkoutSession] {
        statsVM.sessions.filter { session in
            session.exercises.contains { $0.exerciseId == exerciseId }
        }
    }

    private var pointsInWindow: [(date: Date, e1rm: Double)] {
        let cutoff = windowCutoff()
        return sessionsContainingExercise.compactMap { session in
            guard let completed = session.completedAt, completed >= cutoff else { return nil }
            let best = bestE1RM(in: session)
            guard best > 0 else { return nil }
            return (completed, best)
        }
        .sorted { $0.date < $1.date }
    }

    private func windowCutoff() -> Date {
        let calendar = Calendar.current
        switch window {
        case .fourWeeks:
            return calendar.date(byAdding: .day, value: -28, to: Date()) ?? .distantPast
        case .twelveWeeks:
            return calendar.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? .distantPast
        case .allTime:
            return .distantPast
        }
    }

    private func bestE1RM(in session: WorkoutSession) -> Double {
        session.exercises
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.sets)
            .compactMap { set -> Double? in
                guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                    return nil
                }
                return weight * (1.0 + Double(set.actualReps) / 30.0)
            }
            .max() ?? 0
    }

    private var heaviestWeight: Double {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.heaviestWeight ?? 0
    }

    private var heaviestReps: Int {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.heaviestWeightReps ?? 0
    }

    private var bestE1RMOverall: Double {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.bestEstimated1RM ?? 0
    }

    // MARK: - View pieces

    private var tilesRow: some View {
        HStack(spacing: 12) {
            tile(title: "Heaviest", value: "\(formatNumber(heaviestWeight))", subtitle: "lbs × \(heaviestReps)")
            tile(title: "Est. 1RM", value: "\(formatNumber(bestE1RMOverall))", subtitle: "lbs")
            tile(title: "Sessions", value: "\(sessionsContainingExercise.count)", subtitle: nil)
        }
    }

    private func tile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(.yellow)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estimated 1RM")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Picker("Window", selection: $window) {
                    ForEach(TimeWindow.allCases) { w in
                        Text(w.label).tag(w)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            let points = pointsInWindow
            if points.isEmpty {
                Text("No sessions in this window")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1rm)
                    )
                    .foregroundStyle(Color.yellow)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1rm)
                    )
                    .foregroundStyle(Color.yellow)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
                .foregroundColor(.white)

            let sessions = sessionsContainingExercise.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }

            ForEach(sessions) { session in
                Button {
                    selectedHistorySession = session
                } label: {
                    sessionCard(session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(relativeDateLabel(session.completedAt ?? session.startedAt))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(session.templateName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            ForEach(setLines(in: session), id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(10)
        .background(Color(hex: "#081f3a"))
        .cornerRadius(8)
    }

    private func setLines(in session: WorkoutSession) -> [String] {
        let exercises = session.exercises.filter { $0.exerciseId == exerciseId }
        let sets = exercises.flatMap(\.sets).filter(\.isCompleted)
        return sets.enumerated().map { index, set in
            let weight = set.actualWeight ?? 0
            let e1rm = weight > 0
                ? weight * (1.0 + Double(set.actualReps) / 30.0)
                : 0
            if weight > 0 {
                return "Set \(index + 1) — \(set.actualReps) × \(formatNumber(weight)) lbs (e1RM \(formatNumber(e1rm)))"
            } else {
                return "Set \(index + 1) — \(set.actualReps) reps"
            }
        }
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}
```

- [ ] **Step 2: Register the navigation destination in `StatsView`**

In `StatsView`'s `body`, attach `.navigationDestination(for: ExerciseDetailDestination.self)` inside the `NavigationStack`. The updated `body` should be:

```swift
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                content
            }
            .navigationTitle("Stats")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: ExerciseDetailDestination.self) { destination in
                ExerciseDetailView(
                    exerciseId: destination.exerciseId,
                    exerciseName: destination.exerciseName
                )
            }
        }
        .task { await vm.loadIfNeeded() }
    }
```

`ExerciseDetailView` reads the shared `StatsViewModel` via `@EnvironmentObject`, which propagates automatically through the navigation stack — no manual `.environmentObject` call needed at the destination.

- [ ] **Step 3: Build the app**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test**

Launch the simulator. Open Stats with ≥1 completed session containing a weighted exercise (e.g., Bench Press). Tap a PR row.

Expected:
- Pushes onto `ExerciseDetailView` with the navigation title set to the exercise name
- Three tiles up top: Heaviest, Est. 1RM, Sessions
- "Estimated 1RM" chart card with its own 4w / 12w / All segmented picker (independent of the Stats tab's picker); yellow line with point markers; empty state when the window contains no sessions
- "History" card lists every session containing this exercise, newest first, with per-set lines `Set N — reps × weight lbs (e1RM …)`
- Tapping a history card opens the existing `SessionSummaryView` as a `.sheet` in `.readOnly` mode; tapping Close dismisses

Navigate back to Stats — the Stats tab's picker selection is preserved (it lives on `StatsViewModel`, not the view), confirming the cache.

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/ExerciseDetailView.swift fitnessApp/StatsView.swift
git commit -m "Add ExerciseDetailView drill-down from PR rows (Group 6)"
```

---

## End-of-plan verification

After Task 7, run the full simulator smoke list one more time end-to-end:

1. Sign in to a test account with several completed sessions
2. Stats tab loads, shows tiles + volume chart + PRs + category split
3. Toggle volume picker through 4w / 12w / All; both the chart and the category split re-render
4. "Show all" expands the PR list past 10 rows
5. Tap a PR row → detail view; toggle its picker; tap a history card → summary sheet; close
6. Go to Workout tab, finish a new session
7. Return to Stats — the new session is reflected (totals incremented, latest PR updated if applicable). This confirms `sessionSavedNotification` invalidation works.
8. Sign out, sign in as a different test account — Stats shows that account's data (or the empty state), not the previous one's. This confirms the `@StateObject` teardown handles user switching.

If everything passes, the Group 6 work is shipped. Update `memory/project-barbellbase-roadmap.md` separately to reflect the new "Completed" entry.

# Active Workout Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken "Start Today's Workout" flow with a real, full-screen active session that logs sets live, runs a rest timer, finishes to a summary screen, and surfaces the completed session in WorkoutView's Recent Workouts row.

**Architecture:** New `WorkoutSession` / `LoggedExercise` / `LoggedSet` Codable models persisted to Firestore at `users/{uid}/sessions/{id}` (written once on Finish — no draft state). Full-screen `.fullScreenCover` modal presents `ActiveSessionView` driven by `@MainActor ActiveSessionViewModel`. Rest timer is a cancellable `Task`. Finished sessions render in WorkoutView via `WorkoutListViewModel.recentSessions` and re-use `SessionSummaryView` for the tap-to-view detail.

**Tech Stack:** SwiftUI, Swift Concurrency (async/await, Task), Firebase Firestore, the project's existing snake_case CodingKeys + singleton manager patterns.

**Testing note:** Per project preference (Defer tests, chosen at Group 3), this plan uses build-verify + manual smoke test instead of unit tests, matching how Groups 1–4 were shipped. Each task ends with `xcodebuild` verification and an explicit manual smoke test before commit.

**Spec:** `docs/superpowers/specs/2026-06-03-active-workout-session-design.md`

---

## File Structure

**New files:**
- `fitnessApp/Models/LoggedSet.swift` — one set within an exercise
- `fitnessApp/Models/LoggedExercise.swift` — one exercise within a session
- `fitnessApp/Models/WorkoutSession.swift` — the session, with `starting(from:userId:)` builder
- `fitnessApp/Firestore/WorkoutSessionManager.swift` — singleton: save / list / get sessions
- `fitnessApp/ActiveSessionView.swift` — full-screen session view + `ActiveSessionViewModel`
- `fitnessApp/SessionSummaryView.swift` — post-finish summary + read-only recent-session detail

**Modified files:**
- `fitnessApp/WorkoutView.swift` — Start button → `.fullScreenCover`; Recent Workouts → real data; refresh after modal dismiss
- `fitnessApp/WorkoutTemplateEditorView.swift` — add "Start Workout" button (edit mode only)

---

## Reusable build command

Throughout the plan, "build the app" means running this from the repo root:

```bash
xcodebuild \
  -project fitnessApp.xcodeproj \
  -scheme fitnessApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | tail -40
```

Expected: `BUILD SUCCEEDED` at the end. New `.swift` files under `fitnessApp/` auto-register via Xcode 16 synced groups — no `project.pbxproj` edits needed. SourceKit "Cannot find X in scope" warnings in the IDE are noise; trust the `xcodebuild` result.

---

### Task 1: Data models

**Files:**
- Create: `fitnessApp/Models/LoggedSet.swift`
- Create: `fitnessApp/Models/LoggedExercise.swift`
- Create: `fitnessApp/Models/WorkoutSession.swift`

- [ ] **Step 1: Create `LoggedSet.swift`**

```swift
//
//  LoggedSet.swift
//  fitnessApp
//

import Foundation

struct LoggedSet: Codable, Identifiable, Hashable {
    let id: String
    let targetReps: Int
    let targetWeight: Double?
    var actualReps: Int
    var actualWeight: Double?
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        targetReps: Int,
        targetWeight: Double?,
        actualReps: Int? = nil,
        actualWeight: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.actualReps = actualReps ?? targetReps
        self.actualWeight = actualWeight ?? targetWeight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case targetReps = "target_reps"
        case targetWeight = "target_weight"
        case actualReps = "actual_reps"
        case actualWeight = "actual_weight"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }
}
```

- [ ] **Step 2: Create `LoggedExercise.swift`**

```swift
//
//  LoggedExercise.swift
//  fitnessApp
//

import Foundation

struct LoggedExercise: Codable, Identifiable, Hashable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    var sets: [LoggedSet]

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sets = sets
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sets
    }
}
```

- [ ] **Step 3: Create `WorkoutSession.swift`**

```swift
//
//  WorkoutSession.swift
//  fitnessApp
//

import Foundation

struct WorkoutSession: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let templateId: String?
    let templateName: String
    let startedAt: Date
    var completedAt: Date?
    var exercises: [LoggedExercise]

    init(
        id: String = UUID().uuidString,
        userId: String,
        templateId: String?,
        templateName: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        exercises: [LoggedExercise] = []
    ) {
        self.id = id
        self.userId = userId
        self.templateId = templateId
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case templateId = "template_id"
        case templateName = "template_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exercises
    }
}

extension WorkoutSession {
    static func starting(from template: WorkoutTemplate, userId: String) -> WorkoutSession {
        let exercises = template.exercises.map { planned in
            LoggedExercise(
                exerciseId: planned.exerciseId,
                exerciseName: planned.exerciseName,
                sets: (0..<planned.targetSets).map { _ in
                    LoggedSet(targetReps: planned.targetReps, targetWeight: planned.targetWeight)
                }
            )
        }
        return WorkoutSession(
            userId: userId,
            templateId: template.id,
            templateName: template.name,
            exercises: exercises
        )
    }
}
```

- [ ] **Step 4: Build the app** (see Reusable build command above)

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/Models/LoggedSet.swift fitnessApp/Models/LoggedExercise.swift fitnessApp/Models/WorkoutSession.swift
git commit -m "$(cat <<'EOF'
Add WorkoutSession data model (Group 5)

LoggedSet / LoggedExercise / WorkoutSession Codable types with snake_case
CodingKeys matching the existing pattern. WorkoutSession.starting(from:userId:)
builds a fresh session from a template, denormalizing template + exercise names.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: WorkoutSessionManager singleton

**Files:**
- Create: `fitnessApp/Firestore/WorkoutSessionManager.swift`

- [ ] **Step 1: Create `WorkoutSessionManager.swift`**

```swift
//
//  WorkoutSessionManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

final class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
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
    }

    func listRecentSessions(userId: String, limit: Int = 5) async throws -> [WorkoutSession] {
        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: WorkoutSession.CodingKeys.completedAt.rawValue, descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutSession.self) }
    }

    func getSession(userId: String, sessionId: String) async throws -> WorkoutSession {
        try await sessionDocument(userId: userId, sessionId: sessionId)
            .getDocument(as: WorkoutSession.self)
    }
}
```

- [ ] **Step 2: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add fitnessApp/Firestore/WorkoutSessionManager.swift
git commit -m "$(cat <<'EOF'
Add WorkoutSessionManager singleton (Group 5)

save / list / get sessions at users/{uid}/sessions/{id}, mirroring the existing
WorkoutTemplateManager pattern. Completed sessions ordered by completed_at desc.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: ActiveSessionView + WorkoutView entry point

This task gets the modal launching and basic set logging working end-to-end. Rest timer, add/remove sets, and summary screen come in later tasks.

**Files:**
- Create: `fitnessApp/ActiveSessionView.swift` (view + `ActiveSessionViewModel`)
- Modify: `fitnessApp/WorkoutView.swift` — replace Start NavigationLink with `.fullScreenCover`; refresh on dismiss

- [ ] **Step 1: Create `ActiveSessionView.swift`** with minimal VM + view (no rest timer, no add/remove yet)

```swift
//
//  ActiveSessionView.swift
//  fitnessApp
//

import SwiftUI

@MainActor
final class ActiveSessionViewModel: ObservableObject {
    @Published var session: WorkoutSession
    @Published var elapsedSeconds: Int = 0
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false
    @Published var didFinish: Bool = false

    private var elapsedTimer: Timer?

    init(session: WorkoutSession) {
        self.session = session
        startElapsedTimer()
    }

    deinit {
        elapsedTimer?.invalidate()
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.session.startedAt))
            }
        }
    }

    var completedSetCount: Int {
        session.exercises.reduce(0) { sum, ex in sum + ex.sets.filter(\.isCompleted).count }
    }

    var totalSetCount: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var canFinish: Bool {
        completedSetCount > 0 && !isSaving
    }

    func toggleSetComplete(exerciseId: String, setId: String) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        var set = session.exercises[eIdx].sets[sIdx]
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        session.exercises[eIdx].sets[sIdx] = set
    }

    func updateReps(exerciseId: String, setId: String, reps: Int) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        session.exercises[eIdx].sets[sIdx].actualReps = reps
    }

    func updateWeight(exerciseId: String, setId: String, weight: Double?) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        session.exercises[eIdx].sets[sIdx].actualWeight = weight
    }

    func finish() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        var done = session
        done.completedAt = Date()
        do {
            try await WorkoutSessionManager.shared.saveCompletedSession(done)
            session = done
            didFinish = true
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save workout. Try again."
        }
    }
}

struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveSessionViewModel
    @State private var showingDiscardConfirm = false

    init(template: WorkoutTemplate, userId: String) {
        let session = WorkoutSession.starting(from: template, userId: userId)
        _viewModel = StateObject(wrappedValue: ActiveSessionViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.session.exercises) { exercise in
                            exerciseCard(exercise)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
                finishBar
            }
        }
        .alert("Discard workout?", isPresented: $showingDiscardConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your logged sets won't be saved.")
        }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished { dismiss() }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.session.templateName)
                    .font(.headline)
                    .foregroundColor(.yellow)
                Text(formatElapsed(viewModel.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button {
                showingDiscardConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(hex: "#06152a"))
    }

    private func exerciseCard(_ exercise: LoggedExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(exercise.sets.filter(\.isCompleted).count) / \(exercise.sets.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exerciseId: exercise.id, set: set, index: index)
            }
        }
        .padding()
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func setRow(exerciseId: String, set: LoggedSet, index: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.toggleSetComplete(exerciseId: exerciseId, setId: set.id)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .yellow : .white.opacity(0.5))
                    .font(.title3)
            }
            Text("Set \(index + 1)")
                .foregroundColor(.white.opacity(set.isCompleted ? 0.5 : 1.0))
                .frame(width: 56, alignment: .leading)
            repsField(exerciseId: exerciseId, set: set)
            weightField(exerciseId: exerciseId, set: set)
        }
    }

    private func repsField(exerciseId: String, set: LoggedSet) -> some View {
        let binding = Binding<String>(
            get: { String(set.actualReps) },
            set: { viewModel.updateReps(exerciseId: exerciseId, setId: set.id, reps: Int($0) ?? 0) }
        )
        return HStack(spacing: 4) {
            TextField("0", text: binding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .padding(.vertical, 4)
                .background(Color(hex: "#06152a"))
                .foregroundColor(.white)
                .cornerRadius(6)
            Text("reps")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func weightField(exerciseId: String, set: LoggedSet) -> some View {
        let binding = Binding<String>(
            get: { set.actualWeight.map { formatWeight($0) } ?? "" },
            set: { viewModel.updateWeight(exerciseId: exerciseId, setId: set.id, weight: Double($0)) }
        )
        return HStack(spacing: 4) {
            TextField("—", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 56)
                .padding(.vertical, 4)
                .background(Color(hex: "#06152a"))
                .foregroundColor(.white)
                .cornerRadius(6)
            Text("lbs")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var finishBar: some View {
        Button {
            Task { await viewModel.finish() }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView().tint(Color(hex: "#081f3a"))
                }
                Text("Finish Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canFinish ? Color.yellow : Color.yellow.opacity(0.4))
            .foregroundColor(Color(hex: "#081f3a"))
            .cornerRadius(10)
        }
        .disabled(!viewModel.canFinish)
        .padding()
        .background(Color(hex: "#06152a"))
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
```

- [ ] **Step 2: Modify `WorkoutView.swift`** — replace `startTodayButton`'s NavigationLink with a `.fullScreenCover` trigger

Open `fitnessApp/WorkoutView.swift`. At the top of the `WorkoutView` struct, add a state variable for presenting the session:

```swift
struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutListViewModel()
    @State private var presentingSessionFor: WorkoutTemplate?
```

Replace the existing `startTodayButton` (the `if let template = ..., let uid = ...` branch) with:

```swift
    @ViewBuilder
    private var startTodayButton: some View {
        if let template = viewModel.todaysTemplate, viewModel.userId != nil {
            Button {
                presentingSessionFor = template
            } label: {
                VStack(spacing: 4) {
                    Text("Start Today's Workout")
                        .fontWeight(.semibold)
                    Text(template.name)
                        .font(.caption)
                        .opacity(0.8)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        } else {
            VStack(spacing: 4) {
                Text("No Workout Scheduled for \(Weekday.today.displayName)")
                    .fontWeight(.semibold)
                Text("Assign one in your weekly plan.")
                    .font(.caption)
                    .opacity(0.8)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.yellow.opacity(0.2))
            .foregroundColor(.yellow)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
        }
    }
```

At the end of the `body`'s outer `NavigationStack` block (after `.task { ... }`), attach the `.fullScreenCover`:

```swift
            .fullScreenCover(item: $presentingSessionFor) { template in
                if let uid = viewModel.userId {
                    ActiveSessionView(template: template, userId: uid)
                        .onDisappear {
                            Task { await viewModel.load() }
                        }
                }
            }
```

- [ ] **Step 3: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test in the simulator**

Run the app. Sign in if needed. Assign a template to today's weekday in Weekly Plan if you haven't already (create a "Test Push" workout with 2–3 exercises first). Then:

1. From Workout tab, tap **Start Today's Workout** — full-screen modal appears, tab bar hidden
2. Top bar shows the template name and a ticking elapsed clock
3. Tap a set's circle — it becomes a yellow filled checkmark, "Set N" text dims
4. Edit a reps field — value persists
5. Edit a weight field — value persists
6. Tap **Finish Workout** — modal dismisses, you're back on Workout tab
7. Sign out and back in — open Firestore (or trust it works); the session document should exist at `users/{uid}/sessions/{id}` with the logged sets

Tap ✕ during a separate session → "Discard workout?" alert appears → Discard dismisses without saving.

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/ActiveSessionView.swift fitnessApp/WorkoutView.swift
git commit -m "$(cat <<'EOF'
Add ActiveSessionView with set logging + finish (Group 5)

Full-screen modal session presented from WorkoutView's Start Today's Workout
button. ActiveSessionViewModel owns the in-flight session in memory; sets are
toggle-completable with editable reps/weight TextFields. Finish saves to
Firestore via WorkoutSessionManager; ✕ shows a discard-confirm alert. Workout
tab refreshes on modal dismiss.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Rest timer

**Files:**
- Modify: `fitnessApp/ActiveSessionView.swift`

- [ ] **Step 1: Add rest-timer state + methods to `ActiveSessionViewModel`**

Add these published properties near the existing `@Published` declarations:

```swift
    @Published var restRemaining: Int? = nil
```

Add a private property next to `elapsedTimer`:

```swift
    private var restTask: Task<Void, Never>?
```

Update `deinit` to also cancel the rest task:

```swift
    deinit {
        elapsedTimer?.invalidate()
        restTask?.cancel()
    }
```

Add these methods to the view model:

```swift
    private static let restDurationSeconds = 90

    func startRest() {
        restTask?.cancel()
        restRemaining = Self.restDurationSeconds
        restTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run {
                    guard let self, let r = self.restRemaining else { return }
                    if r <= 1 {
                        self.restRemaining = nil
                    } else {
                        self.restRemaining = r - 1
                    }
                }
                let stop = await MainActor.run { self?.restRemaining == nil }
                if stop { break }
            }
        }
    }

    func adjustRest(by delta: Int) {
        guard let r = restRemaining else { return }
        restRemaining = max(0, r + delta)
    }

    func skipRest() {
        restTask?.cancel()
        restTask = nil
        restRemaining = nil
    }
```

In `toggleSetComplete`, after the `session.exercises[eIdx].sets[sIdx] = set` line, add a call to `startRest()` when a set transitions to completed:

```swift
    func toggleSetComplete(exerciseId: String, setId: String) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        var set = session.exercises[eIdx].sets[sIdx]
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        session.exercises[eIdx].sets[sIdx] = set
        if set.isCompleted {
            startRest()
        }
    }
```

- [ ] **Step 2: Add rest pill UI to `ActiveSessionView`**

In the `body`, sit the rest pill above the `finishBar`. Replace the existing `VStack(spacing: 0)` body inside the `ZStack` with:

```swift
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.session.exercises) { exercise in
                            exerciseCard(exercise)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
                if let remaining = viewModel.restRemaining {
                    restPill(remaining: remaining)
                }
                finishBar
            }
```

Add the `restPill` helper view inside `ActiveSessionView`:

```swift
    private func restPill(remaining: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(formatElapsed(remaining))
                    .font(.title3.monospacedDigit())
                    .foregroundColor(.yellow)
            }
            Spacer()
            Button("−15s") { viewModel.adjustRest(by: -15) }
                .buttonStyle(.bordered)
                .tint(.yellow)
            Button("+15s") { viewModel.adjustRest(by: 15) }
                .buttonStyle(.bordered)
                .tint(.yellow)
            Button("Skip") { viewModel.skipRest() }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
        }
        .padding()
        .background(Color(hex: "#0c2548"))
    }
```

- [ ] **Step 3: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test**

1. Start a session
2. Tap a set's circle to complete it → rest pill appears at bottom with "Rest 1:30" counting down
3. Tap **+15s** → time jumps up
4. Tap **−15s** → time drops
5. Tap **Skip** → pill disappears
6. Complete another set → fresh 90s rest starts
7. Complete a set, then quickly complete another → the second start resets the timer to 90s (previous task cancelled)
8. Untoggle a completed set (tap its checkmark again) → it un-completes, no new timer starts
9. Let the timer run to 0:00 → pill auto-dismisses

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/ActiveSessionView.swift
git commit -m "$(cat <<'EOF'
Add rest timer to active session (Group 5)

Auto-starts a 90s rest countdown when a set is marked complete. Pill UI sits
above the Finish bar with −15s / +15s / Skip controls. Marking another set
complete during rest cancels and restarts the timer. Timer is a cancellable
Task; backgrounding is best-effort and may drift.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Add/remove sets mid-session

**Files:**
- Modify: `fitnessApp/ActiveSessionView.swift`

- [ ] **Step 1: Add `addSet` and `removeSet` methods to `ActiveSessionViewModel`**

```swift
    func addSet(exerciseId: String) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let lastSet = session.exercises[eIdx].sets.last
        let newSet = LoggedSet(
            targetReps: lastSet?.targetReps ?? 8,
            targetWeight: lastSet?.targetWeight,
            actualReps: lastSet?.actualReps,
            actualWeight: lastSet?.actualWeight
        )
        session.exercises[eIdx].sets.append(newSet)
    }

    func removeSet(exerciseId: String, setId: String) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        session.exercises[eIdx].sets.removeAll { $0.id == setId }
    }
```

- [ ] **Step 2: Update `exerciseCard` to include an "Add Set" button and swipe-to-delete on each row**

Replace `exerciseCard` with:

```swift
    private func exerciseCard(_ exercise: LoggedExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(exercise.sets.filter(\.isCompleted).count) / \(exercise.sets.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exerciseId: exercise.id, set: set, index: index)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeSet(exerciseId: exercise.id, setId: set.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Button {
                viewModel.addSet(exerciseId: exercise.id)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.yellow)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
```

Note: `swipeActions` requires the rows to be inside a `List` for swipe gestures to work consistently. Since the rows are currently inside a `VStack` inside a `ScrollView`, swipe-to-delete won't trigger from a `VStack`. To keep the existing card visual but get swipe behavior, wrap each set row in a `List`-style container... actually, simpler: keep the row tap-to-toggle and add a long-press delete instead.

Replace the `swipeActions` modifier on the `setRow` call with a context menu:

```swift
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exerciseId: exercise.id, set: set, index: index)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeSet(exerciseId: exercise.id, setId: set.id)
                        } label: {
                            Label("Delete Set", systemImage: "trash")
                        }
                    }
            }
```

- [ ] **Step 3: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test**

1. Start a session
2. Tap **Add Set** on the first exercise → a new row appears with the previous set's values
3. Complete the new set → checkmark + rest timer starts
4. Long-press a set row → "Delete Set" context menu appears → tap it → set disappears
5. Long-press the last remaining set on an exercise → delete it → exercise card shows "0 / 0", "Add Set" still works
6. Add several sets, complete some, delete some → counts update correctly

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/ActiveSessionView.swift
git commit -m "$(cat <<'EOF'
Allow add/remove sets during active session (Group 5)

Per-exercise 'Add Set' button copies the last set's values as defaults.
Long-press a set row to delete it via context menu (works inside the
ScrollView/VStack layout where swipeActions can't fire). Completed-set
counts update automatically.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: SessionSummaryView + finish transition

**Files:**
- Create: `fitnessApp/SessionSummaryView.swift`
- Modify: `fitnessApp/ActiveSessionView.swift` — transition to summary instead of immediate dismiss

- [ ] **Step 1: Create `SessionSummaryView.swift`**

```swift
//
//  SessionSummaryView.swift
//  fitnessApp
//

import SwiftUI

struct SessionSummaryView: View {
    enum Mode {
        case finish   // Done button, shows "Workout Complete" header
        case readOnly // Close button, shows template name as header
    }

    let session: WorkoutSession
    let mode: Mode
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statRow
                    exerciseBreakdown
                }
                .padding()
            }
            VStack {
                Spacer()
                doneButton
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mode == .finish ? "Workout Complete" : session.templateName)
                .font(.largeTitle.bold())
                .foregroundColor(.yellow)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var subtitle: String {
        let date = session.completedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if mode == .finish {
            return "\(session.templateName) · \(formatter.string(from: date))"
        }
        return formatter.string(from: date)
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statTile(label: "Duration", value: durationString)
            statTile(label: "Sets", value: "\(completedSets)/\(totalSets)")
            statTile(label: "Volume", value: "\(volumeString) lbs")
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundColor(.yellow)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 8)
            ForEach(session.exercises) { exercise in
                exerciseSummary(exercise)
            }
            Color.clear.frame(height: 80)
        }
    }

    private func exerciseSummary(_ exercise: LoggedExercise) -> some View {
        let completed = exercise.sets.filter(\.isCompleted)
        return VStack(alignment: .leading, spacing: 6) {
            Text(exercise.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            if completed.isEmpty {
                Text("No sets completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            } else {
                ForEach(Array(completed.enumerated()), id: \.element.id) { index, set in
                    Text("Set \(index + 1) — \(set.actualReps) × \(formatWeight(set.actualWeight))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var doneButton: some View {
        Button {
            onDismiss()
        } label: {
            Text(mode == .finish ? "Done" : "Close")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(hex: "#06152a"))
    }

    private var durationString: String {
        let end = session.completedAt ?? Date()
        let total = Int(end.timeIntervalSince(session.startedAt))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var completedSets: Int {
        session.exercises.reduce(0) { sum, ex in sum + ex.sets.filter(\.isCompleted).count }
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var volumeString: String {
        let total = session.exercises.flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.actualReps) * ($1.actualWeight ?? 0) }
        return formatWeight(total)
    }

    private func formatWeight(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
```

- [ ] **Step 2: Update `ActiveSessionView` to transition to the summary on finish instead of dismissing**

Remove the `.onChange(of: viewModel.didFinish)` modifier from `ActiveSessionView`'s body. Replace the outer body's `ZStack { ... }` with a conditional:

```swift
    var body: some View {
        Group {
            if viewModel.didFinish {
                SessionSummaryView(session: viewModel.session, mode: .finish) {
                    dismiss()
                }
            } else {
                sessionBody
            }
        }
        .alert("Discard workout?", isPresented: $showingDiscardConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your logged sets won't be saved.")
        }
    }

    private var sessionBody: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.session.exercises) { exercise in
                            exerciseCard(exercise)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
                if let remaining = viewModel.restRemaining {
                    restPill(remaining: remaining)
                }
                finishBar
            }
        }
    }
```

- [ ] **Step 3: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test**

1. Start a session, log a few sets across two exercises, tap **Finish Workout**
2. Modal body swaps to **Workout Complete** summary screen
3. Three stat tiles show Duration / Sets / Volume — values look right
4. Exercises list shows completed sets per exercise, with reps × weight; uncompleted sets are not listed
5. Tap **Done** → modal dismisses, you're on the Workout tab
6. Start another session, only complete one set, finish → summary shows just that one set

- [ ] **Step 5: Commit**

```bash
git add fitnessApp/SessionSummaryView.swift fitnessApp/ActiveSessionView.swift
git commit -m "$(cat <<'EOF'
Add SessionSummaryView after Finish (Group 5)

Post-finish, the modal body transitions to SessionSummaryView showing
duration / sets / total-volume stat tiles plus a per-exercise breakdown of
completed sets. 'Done' dismisses the modal. SessionSummaryView is reusable
in read-only mode for the upcoming Recent Workouts tap.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Recent Workouts wiring in WorkoutView

**Files:**
- Modify: `fitnessApp/WorkoutView.swift` — load recent sessions, render cards, add `.sheet` to summary

- [ ] **Step 1: Add `recentSessions` state + load it in `WorkoutListViewModel`**

In `WorkoutListViewModel`, add:

```swift
    @Published private(set) var recentSessions: [WorkoutSession] = []
```

Update `load()` to also fetch sessions in parallel:

```swift
    func load() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let templatesTask = WorkoutTemplateManager.shared.listTemplates(userId: uid)
            async let scheduleTask = ScheduleManager.shared.getSchedule(userId: uid)
            async let recentTask = WorkoutSessionManager.shared.listRecentSessions(userId: uid, limit: 5)
            let loadedTemplates = try await templatesTask
            let schedule = try await scheduleTask
            let loadedSessions = try await recentTask
            self.templates = loadedTemplates
            self.todaysTemplateId = schedule.assignments[.today]
            self.recentSessions = loadedSessions
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load workouts."
        }
    }
```

- [ ] **Step 2: Add a `selectedRecentSession` state and a `.sheet` to `WorkoutView`**

Add another `@State` near `presentingSessionFor`:

```swift
    @State private var selectedRecentSession: WorkoutSession?
```

Attach a `.sheet` next to the existing `.fullScreenCover`:

```swift
            .sheet(item: $selectedRecentSession) { session in
                SessionSummaryView(session: session, mode: .readOnly) {
                    selectedRecentSession = nil
                }
                .presentationDetents([.medium, .large])
            }
```

- [ ] **Step 3: Replace the `recentWorkoutsRow` body**

Replace the existing `recentWorkoutsRow` with:

```swift
    @ViewBuilder
    private var recentWorkoutsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                if viewModel.recentSessions.isEmpty {
                    VStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.25))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "clock")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                            )
                        Text("No workouts yet")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.footnote)
                    }
                } else {
                    ForEach(viewModel.recentSessions) { session in
                        Button {
                            selectedRecentSession = session
                        } label: {
                            recentSessionCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func recentSessionCard(_ session: WorkoutSession) -> some View {
        VStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(session.templateName.prefix(1)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#081f3a"))
                )
            Text(session.templateName)
                .foregroundColor(.white)
                .font(.footnote)
                .lineLimit(1)
            Text(relativeDate(session.completedAt ?? session.startedAt))
                .foregroundColor(.white.opacity(0.6))
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 90)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
```

- [ ] **Step 4: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke test**

1. Open Workout tab. Recent Workouts row shows the "No workouts yet" empty card (assuming you don't have prior sessions on this account)
2. Start a workout, complete a set, tap Finish, tap Done. Recent Workouts row now shows one card with the template's first letter, name, and "Today"
3. Tap the card → bottom sheet appears with the summary screen, "Close" button at the bottom
4. Dismiss the sheet → Workout tab still shows the card
5. Pull to refresh on the Workout tab → row stays consistent
6. Do another session today → second card appears
7. Edit a session indirectly: rename the template, sign out, sign back in. The Recent Workouts card still shows the original `templateName` (denormalized — confirms the design works)

- [ ] **Step 6: Commit**

```bash
git add fitnessApp/WorkoutView.swift
git commit -m "$(cat <<'EOF'
Wire Recent Workouts row to real sessions (Group 5)

WorkoutListViewModel loads the 5 most recent completed sessions in parallel
with templates + schedule. Cards show template initial + relative date and
tap into a SessionSummaryView in read-only mode. Empty state replaces the
previous 'Coming Soon' placeholder.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: "Start Workout" button on the template editor

**Files:**
- Modify: `fitnessApp/WorkoutTemplateEditorView.swift`

- [ ] **Step 1: Add Start state + button in edit mode**

Open `fitnessApp/WorkoutTemplateEditorView.swift`. Add a `@State` near the existing `showingAddExercise` / `showingDeleteConfirm`:

```swift
    @State private var presentingSession: Bool = false
```

In the body's VStack, between `saveButton` and the existing `if viewModel.isEditing { deleteButton }`, add a Start button so the order becomes Save → Start → Delete:

```swift
                saveButton

                if viewModel.isEditing {
                    startButton
                    deleteButton
                }
```

Add the new computed view:

```swift
    private var startButton: some View {
        Button {
            presentingSession = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow.opacity(0.2))
            .foregroundColor(.yellow)
            .cornerRadius(10)
        }
        .disabled(viewModel.exercises.isEmpty)
        .padding(.horizontal)
    }
```

- [ ] **Step 2: Expose a snapshot helper on the editor view model**

In `WorkoutTemplateEditorViewModel` (inside the same file), expose the original template id and add a helper that builds a `WorkoutTemplate` from current in-memory state. Replace the existing `private let existingId: String?` with internal visibility, and add the helper:

```swift
    let existingId: String?
```

(Change `private let existingId` → `let existingId`.) Then add the helper after `var isEditing: Bool { existingId != nil }`:

```swift
    var snapshotForSession: WorkoutTemplate? {
        guard let existingId else { return nil }
        return WorkoutTemplate(
            id: existingId,
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : name,
            exercises: exercises,
            dateCreated: dateCreated,
            dateUpdated: Date()
        )
    }
```

This carries the real persisted `existingId` through into the session (so `templateId` on the saved `WorkoutSession` is non-nil and accurate), but uses the current edited `name` and `exercises` so unsaved tweaks are reflected in the live session.

- [ ] **Step 3: Attach the `.fullScreenCover`**

After the existing `.alert("Delete Workout?", ...)` modifier on the editor's body, add:

```swift
        .fullScreenCover(isPresented: $presentingSession) {
            if let template = viewModel.snapshotForSession {
                ActiveSessionView(template: template, userId: viewModel.userId)
            }
        }
```

- [ ] **Step 4: Build the app**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual smoke test**

1. Workout tab → tap a routine circle → editor opens for that template
2. **Start Workout** button is visible above Delete; it's enabled because the template has exercises
3. Tap **Start Workout** → full-screen session modal appears with that template's exercises
4. Complete a set, finish, Done → back on the editor screen
5. Tap a routine in the Routines row → editor → Start, complete, finish → Recent Workouts on Workout tab includes both sessions
6. Edit mode: open an existing template, edit name to "Push Day v2", tap **Start Workout** without saving → session top bar shows "Push Day v2"
7. Create a brand-new template via "Add Routine" — Start button does NOT appear (only edit mode shows it)
8. Open a template, remove all exercises → Start button is disabled (greyed)

- [ ] **Step 6: Commit**

```bash
git add fitnessApp/WorkoutTemplateEditorView.swift
git commit -m "$(cat <<'EOF'
Add Start Workout button to template editor (Group 5)

In edit mode, a Start Workout button presents the full-screen session
modal using the editor's current in-memory exercises. Disabled when the
template has no exercises. Not shown in create mode (no template to start
from yet).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Done

After Task 8, Group 5 is complete:
- Active session modal works from both entry points
- Sets are logged with editable reps/weight, add/remove supported
- Rest timer auto-runs 90s with adjustments + skip
- Finish screen summarises duration / sets / volume
- Recent Workouts row shows finished sessions and opens a read-only summary

Known follow-ups (not in scope, called out in the spec):
- Stale Schedule references after template delete (unchanged from current)
- Stats tab data wiring (Group 6)
- Background-friendly rest timer
- Session editing post-finish

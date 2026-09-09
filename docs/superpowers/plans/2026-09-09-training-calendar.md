# Training Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI current-week training calendar with deterministic bundled workout data, SwiftData cache-first loading, and completion toggles persisted by workout ID.

**Architecture:** A `@MainActor` MVVM presentation layer consumes a repository that owns bundled-fixture refresh and SwiftData persistence. Pure calendar and status services isolate date math; focused SwiftUI components render immutable day and workout presentation models.

**Tech Stack:** Swift 5 mode, SwiftUI, Observation, SwiftData, Swift Concurrency, Swift Testing, XCTest UI testing, iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-09-training-calendar-design.md`

## Global Constraints

- Display only the current Monday-through-Sunday week; do not add week navigation.
- Use a bundled `workouts.json` fixture; do not call the Mockable endpoint or any network service.
- Support zero or more workouts per day and toggle every workout, including future workouts, by stable ID.
- Resolve status in this order: completed, missed past workout, assigned today, grey future workout.
- Persist explicit `true` and `false` completion overrides separately from refreshed workout definitions.
- Keep all seven dates visible during loading and error states.
- Use the Figma node `23776:49540` as the source of truth for measured visual tokens.
- Use Apple frameworks only and support iOS 17 or later.
- Run tests on `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5`.

## File Structure

```text
TrainingCalendar/
├── App/
│   └── TrainingCalendarApp.swift        # Model container and production dependency wiring
├── Data/
│   ├── Fixture/
│   │   ├── BundledWorkoutFixtureSource.swift
│   │   ├── WorkoutFixtureDTO.swift
│   │   └── workouts.json
│   ├── Persistence/
│   │   ├── CachedWorkout.swift
│   │   └── WorkoutCompletionOverride.swift
│   └── WorkoutRepository.swift          # Cache, refresh merge, and toggle transaction
├── DesignSystem/
│   └── CalendarDesignTokens.swift       # Figma-measured visual constants
├── Domain/
│   ├── CurrentWeekBuilder.swift
│   ├── WorkoutDefinition.swift
│   └── WorkoutStatus.swift
└── Features/TrainingCalendar/
    ├── DayContainerView.swift
    ├── TrainingCalendarScreen.swift
    ├── TrainingCalendarViewModel.swift
    ├── TrainingCalendarViewState.swift
    └── WorkoutCardView.swift

TrainingCalendarTests/
├── CurrentWeekBuilderTests.swift
├── BundledWorkoutFixtureSourceTests.swift
├── WorkoutRepositoryTests.swift
├── WorkoutStatusResolverTests.swift
└── TrainingCalendarViewModelTests.swift

TrainingCalendarUITests/
└── TrainingCalendarUITests.swift
```

The Xcode project already uses `PBXFileSystemSynchronizedRootGroup`, so files placed under the target directories are automatically included. Remove the template `ContentView.swift`, `Item.swift`, and placeholder test after their replacements are wired.

---

### Task 1: Establish the iOS Baseline and Pure Domain Rules

**Files:**
- Create: `.gitignore`
- Modify: `TrainingCalendar.xcodeproj/project.pbxproj`
- Create: `TrainingCalendar/Domain/WorkoutDefinition.swift`
- Create: `TrainingCalendar/Domain/CurrentWeekBuilder.swift`
- Create: `TrainingCalendar/Domain/WorkoutStatus.swift`
- Create: `TrainingCalendarTests/CurrentWeekBuilderTests.swift`
- Create: `TrainingCalendarTests/WorkoutStatusResolverTests.swift`

**Interfaces:**
- Produces: `WorkoutDefinition`, `WorkoutDisplayStatus`, `CurrentWeekBuilder.days(containing:calendar:)`, and `WorkoutStatusResolver.resolve(scheduledDate:today:isCompleted:calendar:)`.
- Consumes: Foundation `Date` and `Calendar` only.

- [ ] **Step 1: Initialize version control and capture the untouched starter**

Create `.gitignore` with:

```gitignore
.DS_Store
DerivedData/
*.xcuserstate
xcuserdata/
```

Run:

```bash
git init
git add .gitignore TrainingCalendar.xcodeproj TrainingCalendar TrainingCalendarTests TrainingCalendarUITests "Everfit_Mobile_Test Guide.pdf" docs
git commit -m "chore: capture training calendar starter"
```

Expected: a root commit records the starter project, PDF, approved spec, and this plan.

- [ ] **Step 2: Restrict the project to iOS and set the deployment floor**

In every app, unit-test, and UI-test Debug/Release configuration in `project.pbxproj`:

```text
IPHONEOS_DEPLOYMENT_TARGET = 17.0;
SDKROOT = iphoneos;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
TARGETED_DEVICE_FAMILY = "1,2";
```

Remove `MACOSX_DEPLOYMENT_TARGET`, `XROS_DEPLOYMENT_TARGET`, and platform-specific run paths. Keep the existing Swift language and actor-isolation settings.

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Write failing week and status tests**

Create `CurrentWeekBuilderTests.swift`:

```swift
import Foundation
import Testing
@testable import TrainingCalendar

struct CurrentWeekBuilderTests {
    @Test func buildsMondayThroughSundayAcrossYearBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        let now = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 12)))

        let days = try CurrentWeekBuilder.days(containing: now, calendar: calendar)

        #expect(days.count == 7)
        let monday = calendar.dateComponents([.year, .month, .day], from: days[0])
        let sunday = calendar.dateComponents([.year, .month, .day], from: days[6])
        #expect(monday.year == 2026 && monday.month == 12 && monday.day == 28)
        #expect(sunday.year == 2027 && sunday.month == 1 && sunday.day == 3)
    }

    @Test func remainsMondayFirstForSundayFirstLocale() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9)))

        let days = try CurrentWeekBuilder.days(containing: now, calendar: calendar)

        #expect(calendar.component(.weekday, from: days[0]) == 2)
        #expect(calendar.component(.weekday, from: days[6]) == 1)
    }
}
```

Create `WorkoutStatusResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import TrainingCalendar

struct WorkoutStatusResolverTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test(arguments: [
        (-1, false, WorkoutDisplayStatus.missed),
        (0, false, WorkoutDisplayStatus.assigned),
        (1, false, WorkoutDisplayStatus.future),
        (-1, true, WorkoutDisplayStatus.completed),
        (0, true, WorkoutDisplayStatus.completed),
        (1, true, WorkoutDisplayStatus.completed)
    ])
    func resolvesStatus(dayOffset: Int, isCompleted: Bool, expected: WorkoutDisplayStatus) throws {
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12)))
        let scheduled = try #require(calendar.date(byAdding: .day, value: dayOffset, to: today))

        let result = WorkoutStatusResolver.resolve(
            scheduledDate: scheduled,
            today: today,
            isCompleted: isCompleted,
            calendar: calendar
        )

        #expect(result == expected)
    }
}
```

- [ ] **Step 4: Run the tests and verify they fail for missing domain types**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarTests/CurrentWeekBuilderTests -only-testing:TrainingCalendarTests/WorkoutStatusResolverTests
```

Expected: compilation fails because `CurrentWeekBuilder`, `WorkoutDisplayStatus`, and `WorkoutStatusResolver` do not exist.

- [ ] **Step 5: Implement the domain values and pure services**

Create `WorkoutDefinition.swift`:

```swift
import Foundation

struct WorkoutDefinition: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let exerciseCount: Int
    let weekdayOffset: Int
    let initiallyCompleted: Bool
    let sortOrder: Int
}
```

Create `CurrentWeekBuilder.swift`:

```swift
import Foundation

enum CurrentWeekBuilderError: Error {
    case cannotDetermineMonday
    case cannotCreateDay(Int)
}

enum CurrentWeekBuilder {
    static func days(containing date: Date, calendar source: Calendar) throws -> [Date] {
        var calendar = source
        calendar.firstWeekday = 2
        let normalized = calendar.startOfDay(for: date)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: normalized) else {
            throw CurrentWeekBuilderError.cannotDetermineMonday
        }
        return try (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                throw CurrentWeekBuilderError.cannotCreateDay(offset)
            }
            return calendar.startOfDay(for: day)
        }
    }
}
```

Create `WorkoutStatus.swift`:

```swift
import Foundation

enum WorkoutDisplayStatus: Equatable, Sendable {
    case missed
    case assigned
    case future
    case completed

    var label: String? {
        switch self {
        case .missed: "Missed"
        case .assigned: "Assigned"
        case .completed: "Completed"
        case .future: nil
        }
    }
}

enum WorkoutStatusResolver {
    static func resolve(
        scheduledDate: Date,
        today: Date,
        isCompleted: Bool,
        calendar: Calendar
    ) -> WorkoutDisplayStatus {
        if isCompleted { return .completed }
        let scheduledDay = calendar.startOfDay(for: scheduledDate)
        let currentDay = calendar.startOfDay(for: today)
        if scheduledDay < currentDay { return .missed }
        if scheduledDay == currentDay { return .assigned }
        return .future
    }
}
```

- [ ] **Step 6: Run domain tests and commit**

Run the command from Step 4. Expected: all selected tests pass.

```bash
git add TrainingCalendar.xcodeproj/project.pbxproj TrainingCalendar/Domain TrainingCalendarTests/CurrentWeekBuilderTests.swift TrainingCalendarTests/WorkoutStatusResolverTests.swift
git commit -m "feat: add current week and workout status rules"
```

---

### Task 2: Add and Validate the Asynchronous Bundled Fixture

**Files:**
- Create: `TrainingCalendar/Data/Fixture/WorkoutFixtureDTO.swift`
- Create: `TrainingCalendar/Data/Fixture/BundledWorkoutFixtureSource.swift`
- Create: `TrainingCalendar/Data/Fixture/workouts.json`
- Create: `TrainingCalendarTests/BundledWorkoutFixtureSourceTests.swift`

**Interfaces:**
- Consumes: `WorkoutDefinition` from Task 1.
- Produces: `WorkoutFixtureSource.load() async throws -> [WorkoutDefinition]` and `BundledWorkoutFixtureSource`.

- [ ] **Step 1: Write failing fixture tests**

Create a test-only `Bundle.module` substitute by writing JSON to a temporary file and initialize the source with a URL:

```swift
import Foundation
import Testing
@testable import TrainingCalendar

struct BundledWorkoutFixtureSourceTests {
    @Test func decodesValidFixtureAndAssignsStableSortOrder() async throws {
        let url = try fixtureURL(contents: """
        [
          {"id":"a","name":"First","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false},
          {"id":"b","name":"Second","exerciseCount":2,"weekdayOffset":0,"initiallyCompleted":true}
        ]
        """)

        let result = try await BundledWorkoutFixtureSource(url: url).load()

        #expect(result.map(\.id) == ["a", "b"])
        #expect(result.map(\.sortOrder) == [0, 1])
    }

    @Test func rejectsDuplicateIDs() async throws {
        let url = try fixtureURL(contents: """
        [
          {"id":"same","name":"First","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false},
          {"id":"same","name":"Second","exerciseCount":2,"weekdayOffset":1,"initiallyCompleted":false}
        ]
        """)

        await #expect(throws: WorkoutFixtureError.duplicateID("same")) {
            try await BundledWorkoutFixtureSource(url: url).load()
        }
    }

    private func fixtureURL(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension("json")
        try Data(contents.utf8).write(to: url)
        return url
    }
}
```

Add these validation tests to the same type:

```swift
@Test func rejectsInvalidFields() async throws {
    let cases: [(String, WorkoutFixtureError)] = [
        (#"[{"id":" ","name":"Valid","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .emptyID(0)),
        (#"[{"id":"a","name":" ","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .emptyName("a")),
        (#"[{"id":"a","name":"Valid","exerciseCount":-1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .negativeExerciseCount("a")),
        (#"[{"id":"a","name":"Valid","exerciseCount":1,"weekdayOffset":-1,"initiallyCompleted":false}]"#, .invalidWeekdayOffset("a")),
        (#"[{"id":"a","name":"Valid","exerciseCount":1,"weekdayOffset":7,"initiallyCompleted":false}]"#, .invalidWeekdayOffset("a"))
    ]
    for (json, expected) in cases {
        let url = try fixtureURL(contents: json)
        await #expect(throws: expected) { try await BundledWorkoutFixtureSource(url: url).load() }
    }
}

@Test func rejectsMalformedJSON() async throws {
    let url = try fixtureURL(contents: "not-json")
    await #expect(throws: DecodingError.self) {
        try await BundledWorkoutFixtureSource(url: url).load()
    }
}
```

- [ ] **Step 2: Run the fixture tests and verify compilation fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarTests/BundledWorkoutFixtureSourceTests
```

Expected: compilation fails because the fixture source and errors are undefined.

- [ ] **Step 3: Implement DTO decoding and all-or-nothing validation**

Create `WorkoutFixtureDTO.swift`:

```swift
import Foundation

struct WorkoutFixtureDTO: Decodable {
    let id: String
    let name: String
    let exerciseCount: Int
    let weekdayOffset: Int
    let initiallyCompleted: Bool
}

enum WorkoutFixtureError: Error, Equatable {
    case missingResource(String)
    case duplicateID(String)
    case emptyID(Int)
    case emptyName(String)
    case negativeExerciseCount(String)
    case invalidWeekdayOffset(String)
}

protocol WorkoutFixtureSource {
    func load() async throws -> [WorkoutDefinition]
}
```

Create `BundledWorkoutFixtureSource.swift`:

```swift
import Foundation

struct BundledWorkoutFixtureSource: WorkoutFixtureSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "workouts", withExtension: "json") else {
            throw WorkoutFixtureError.missingResource("workouts.json")
        }
        self.url = url
    }

    func load() async throws -> [WorkoutDefinition] {
        let data = try await Task.detached { try Data(contentsOf: url) }.value
        let values = try JSONDecoder().decode([WorkoutFixtureDTO].self, from: data)
        var seen = Set<String>()
        return try values.enumerated().map { index, value in
            let id = value.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { throw WorkoutFixtureError.emptyID(index) }
            guard seen.insert(id).inserted else { throw WorkoutFixtureError.duplicateID(id) }
            guard !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkoutFixtureError.emptyName(id)
            }
            guard value.exerciseCount >= 0 else { throw WorkoutFixtureError.negativeExerciseCount(id) }
            guard (0...6).contains(value.weekdayOffset) else { throw WorkoutFixtureError.invalidWeekdayOffset(id) }
            return WorkoutDefinition(
                id: id,
                name: value.name,
                exerciseCount: value.exerciseCount,
                weekdayOffset: value.weekdayOffset,
                initiallyCompleted: value.initiallyCompleted,
                sortOrder: index
            )
        }
    }
}
```

- [ ] **Step 4: Add the representative Figma-style fixture**

Create `workouts.json`:

```json
[
  {"id":"monday-upper-body","name":"Upper Body Strength","exerciseCount":8,"weekdayOffset":0,"initiallyCompleted":false},
  {"id":"monday-core-mobility","name":"Core & Mobility","exerciseCount":6,"weekdayOffset":0,"initiallyCompleted":true},
  {"id":"tuesday-cardio","name":"Morning Cardio","exerciseCount":5,"weekdayOffset":1,"initiallyCompleted":false},
  {"id":"wednesday-full-body","name":"Full Body Workout","exerciseCount":10,"weekdayOffset":2,"initiallyCompleted":false},
  {"id":"wednesday-recovery","name":"Recovery Stretch","exerciseCount":4,"weekdayOffset":2,"initiallyCompleted":false},
  {"id":"friday-lower-body","name":"Lower Body Strength","exerciseCount":9,"weekdayOffset":4,"initiallyCompleted":false},
  {"id":"saturday-endurance","name":"Weekend Endurance and Conditioning Session","exerciseCount":12,"weekdayOffset":5,"initiallyCompleted":false}
]
```

- [ ] **Step 5: Run fixture tests, verify the resource is bundled, and commit**

Run the Step 2 test command, then:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'generic/platform=iOS Simulator' build | rg 'workouts.json|BUILD SUCCEEDED'
```

Expected: fixture tests pass and build output ends with `BUILD SUCCEEDED`; Xcode's synchronized group copies `workouts.json` into the app resources.

```bash
git add TrainingCalendar/Data/Fixture TrainingCalendarTests/BundledWorkoutFixtureSourceTests.swift
git commit -m "feat: add validated bundled workout fixture"
```

---

### Task 3: Implement SwiftData Cache, Refresh Merge, and Completion Overrides

**Files:**
- Create: `TrainingCalendar/Data/Persistence/CachedWorkout.swift`
- Create: `TrainingCalendar/Data/Persistence/WorkoutCompletionOverride.swift`
- Create: `TrainingCalendar/Data/WorkoutRepository.swift`
- Create: `TrainingCalendarTests/WorkoutRepositoryTests.swift`

**Interfaces:**
- Consumes: `WorkoutDefinition` and `WorkoutFixtureSource`.
- Produces: `WorkoutSnapshot`, `WorkoutRepositoryProtocol`, and `SwiftDataWorkoutRepository`.
- `WorkoutSnapshot.effectiveCompletion(for:) -> Bool` is the only completion merge rule consumed by the view model.

- [ ] **Step 1: Write failing cache-first, merge, and toggle tests**

Use an in-memory model container and a controlled fixture source:

```swift
import SwiftData
import Testing
@testable import TrainingCalendar

@MainActor
struct WorkoutRepositoryTests {
    @Test func refreshPreservesExplicitFalseOverride() async throws {
        let fixture = StubFixtureSource(definitions: [definition(id: "a", initiallyCompleted: true)])
        let repository = try makeRepository(source: fixture)
        _ = try await repository.refresh()
        _ = try await repository.toggleCompletion(workoutID: "a")

        let refreshed = try await repository.refresh()

        #expect(refreshed.effectiveCompletion(for: "a") == false)
    }

    @Test func cachedSnapshotSurvivesRepositoryRecreation() async throws {
        let container = try makeContainer()
        let first = SwiftDataWorkoutRepository(context: container.mainContext, source: StubFixtureSource(definitions: [definition(id: "a")]))
        _ = try await first.refresh()
        _ = try await first.toggleCompletion(workoutID: "a")

        let second = SwiftDataWorkoutRepository(context: container.mainContext, source: StubFixtureSource(definitions: []))
        let cached = try await second.cachedSnapshot()

        #expect(cached.definitions.map(\.id) == ["a"])
        #expect(cached.effectiveCompletion(for: "a") == true)
    }
}
```

Add these repository cases and helpers to the same test file:

```swift
@Test func refreshSortsDefinitionsAndRemovesStaleData() async throws {
    let source = SequenceFixtureSource(responses: [
        [definition(id: "old"), definition(id: "kept", sortOrder: 1)],
        [definition(id: "new", sortOrder: 1), definition(id: "kept", sortOrder: 0)]
    ])
    let repository = try makeRepository(source: source)
    _ = try await repository.refresh()
    _ = try await repository.toggleCompletion(workoutID: "old")

    let result = try await repository.refresh()

    #expect(result.definitions.map(\.id) == ["kept", "new"])
    #expect(result.completionOverrides["old"] == nil)
}

@Test func unknownToggleThrows() async throws {
    let repository = try makeRepository(source: StubFixtureSource(definitions: []))
    await #expect(throws: WorkoutRepositoryError.workoutNotFound("missing")) {
        try await repository.toggleCompletion(workoutID: "missing")
    }
}

private struct StubFixtureSource: WorkoutFixtureSource {
    let definitions: [WorkoutDefinition]
    func load() async throws -> [WorkoutDefinition] { definitions }
}

@MainActor
private final class SequenceFixtureSource: WorkoutFixtureSource {
    private var responses: [[WorkoutDefinition]]
    init(responses: [[WorkoutDefinition]]) { self.responses = responses }
    func load() async throws -> [WorkoutDefinition] { responses.removeFirst() }
}

private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: CachedWorkout.self, WorkoutCompletionOverride.self, configurations: configuration)
}

private func makeRepository(source: any WorkoutFixtureSource) throws -> SwiftDataWorkoutRepository {
    let container = try makeContainer()
    return SwiftDataWorkoutRepository(context: container.mainContext, source: source, now: { Date(timeIntervalSince1970: 1) })
}

private func definition(id: String, initiallyCompleted: Bool = false, sortOrder: Int = 0) -> WorkoutDefinition {
    WorkoutDefinition(id: id, name: id, exerciseCount: 1, weekdayOffset: 0, initiallyCompleted: initiallyCompleted, sortOrder: sortOrder)
}
```

- [ ] **Step 2: Run repository tests and verify they fail for missing persistence types**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarTests/WorkoutRepositoryTests
```

Expected: compilation fails because repository and model types do not exist.

- [ ] **Step 3: Create the SwiftData models**

Create `CachedWorkout.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CachedWorkout {
    @Attribute(.unique) var id: String
    var name: String
    var exerciseCount: Int
    var weekdayOffset: Int
    var initiallyCompleted: Bool
    var sortOrder: Int
    var refreshedAt: Date

    init(definition: WorkoutDefinition, refreshedAt: Date) {
        id = definition.id
        name = definition.name
        exerciseCount = definition.exerciseCount
        weekdayOffset = definition.weekdayOffset
        initiallyCompleted = definition.initiallyCompleted
        sortOrder = definition.sortOrder
        self.refreshedAt = refreshedAt
    }

    var definition: WorkoutDefinition {
        WorkoutDefinition(id: id, name: name, exerciseCount: exerciseCount, weekdayOffset: weekdayOffset, initiallyCompleted: initiallyCompleted, sortOrder: sortOrder)
    }
}
```

Create `WorkoutCompletionOverride.swift`:

```swift
import Foundation
import SwiftData

@Model
final class WorkoutCompletionOverride {
    @Attribute(.unique) var workoutID: String
    var isCompleted: Bool
    var modifiedAt: Date

    init(workoutID: String, isCompleted: Bool, modifiedAt: Date) {
        self.workoutID = workoutID
        self.isCompleted = isCompleted
        self.modifiedAt = modifiedAt
    }
}
```

- [ ] **Step 4: Implement the repository contract and transactional merge**

Create `WorkoutRepository.swift` with these exact public shapes:

```swift
import Foundation
import SwiftData

struct WorkoutSnapshot: Equatable {
    let definitions: [WorkoutDefinition]
    let completionOverrides: [String: Bool]

    static let empty = WorkoutSnapshot(definitions: [], completionOverrides: [:])

    func effectiveCompletion(for workoutID: String) -> Bool {
        guard let definition = definitions.first(where: { $0.id == workoutID }) else { return false }
        return completionOverrides[workoutID] ?? definition.initiallyCompleted
    }
}

enum WorkoutRepositoryError: Error, Equatable {
    case workoutNotFound(String)
}

@MainActor
protocol WorkoutRepositoryProtocol {
    func cachedSnapshot() async throws -> WorkoutSnapshot
    func refresh() async throws -> WorkoutSnapshot
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot
}

@MainActor
final class SwiftDataWorkoutRepository: WorkoutRepositoryProtocol {
    private let context: ModelContext
    private let source: any WorkoutFixtureSource
    private let now: () -> Date

    init(context: ModelContext, source: any WorkoutFixtureSource, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.source = source
        self.now = now
    }

    func cachedSnapshot() async throws -> WorkoutSnapshot { try snapshot() }

    func refresh() async throws -> WorkoutSnapshot {
        let definitions = try await source.load()
        let cached = try context.fetch(FetchDescriptor<CachedWorkout>())
        let overrides = try context.fetch(FetchDescriptor<WorkoutCompletionOverride>())
        let incomingIDs = Set(definitions.map(\.id))
        cached.filter { !incomingIDs.contains($0.id) }.forEach(context.delete)
        overrides.filter { !incomingIDs.contains($0.workoutID) }.forEach(context.delete)

        let byID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        for definition in definitions {
            if let record = byID[definition.id] {
                record.name = definition.name
                record.exerciseCount = definition.exerciseCount
                record.weekdayOffset = definition.weekdayOffset
                record.initiallyCompleted = definition.initiallyCompleted
                record.sortOrder = definition.sortOrder
                record.refreshedAt = now()
            } else {
                context.insert(CachedWorkout(definition: definition, refreshedAt: now()))
            }
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return try snapshot()
    }

    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot {
        let snapshot = try snapshot()
        guard snapshot.definitions.contains(where: { $0.id == workoutID }) else {
            throw WorkoutRepositoryError.workoutNotFound(workoutID)
        }
        let descriptor = FetchDescriptor<WorkoutCompletionOverride>(predicate: #Predicate { $0.workoutID == workoutID })
        let next = !snapshot.effectiveCompletion(for: workoutID)
        if let value = try context.fetch(descriptor).first {
            value.isCompleted = next
            value.modifiedAt = now()
        } else {
            context.insert(WorkoutCompletionOverride(workoutID: workoutID, isCompleted: next, modifiedAt: now()))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return try self.snapshot()
    }

    private func snapshot() throws -> WorkoutSnapshot {
        var descriptor = FetchDescriptor<CachedWorkout>(sortBy: [SortDescriptor(\.sortOrder)])
        descriptor.includePendingChanges = true
        let definitions = try context.fetch(descriptor).map(\.definition)
        let values = try context.fetch(FetchDescriptor<WorkoutCompletionOverride>())
        return WorkoutSnapshot(definitions: definitions, completionOverrides: Dictionary(uniqueKeysWithValues: values.map { ($0.workoutID, $0.isCompleted) }))
    }
}
```

- [ ] **Step 5: Run repository and fixture tests, then commit**

Run the Step 2 command and Task 2's fixture command. Expected: all selected tests pass.

```bash
git add TrainingCalendar/Data TrainingCalendarTests/WorkoutRepositoryTests.swift
git commit -m "feat: cache workouts and completion overrides"
```

---

### Task 4: Build the View Model and Stable Seven-Day Presentation

**Files:**
- Create: `TrainingCalendar/Features/TrainingCalendar/TrainingCalendarViewState.swift`
- Create: `TrainingCalendar/Features/TrainingCalendar/TrainingCalendarViewModel.swift`
- Create: `TrainingCalendarTests/TrainingCalendarViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutRepositoryProtocol`, `CurrentWeekBuilder`, `WorkoutStatusResolver`, and `WorkoutSnapshot`.
- Produces: `DayPresentation`, `WorkoutPresentation`, and observable `TrainingCalendarViewModel` state/actions used by SwiftUI.

- [ ] **Step 1: Write failing view-model tests**

Create deterministic tests around a Wednesday clock:

```swift
import Foundation
import Testing
@testable import TrainingCalendar

@MainActor
struct TrainingCalendarViewModelTests {
    @Test func exposesDatesBeforeSuspendedRefreshAndThenGroupsMultipleWorkouts() async throws {
        let repository = ControlledRepository(cached: .empty)
        let viewModel = makeViewModel(repository: repository)

        let task = Task { await viewModel.load() }
        await repository.waitUntilRefreshStarts()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.phase == .loading)

        repository.finishRefresh(with: snapshot(offsets: [0, 0, 2]))
        await task.value
        #expect(viewModel.days[0].workouts.count == 2)
        #expect(viewModel.days[2].workouts.count == 1)
        #expect(viewModel.phase == .loaded)
    }

    @Test func cachedContentRemainsVisibleWhenRefreshFails() async {
        let repository = FailingRefreshRepository(cached: snapshot(offsets: [1]))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.days[1].workouts.count == 1)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.refreshErrorMessage != nil)
    }

    @Test func toggleUsesWorkoutIDAndPublishesPersistedResult() async {
        let repository = RecordingRepository(snapshot: snapshot(offsets: [5]))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.toggleCompletion(workoutID: "workout-0")

        #expect(repository.toggledIDs == ["workout-0"])
        #expect(viewModel.days[5].workouts[0].status == .completed)
    }
}
```

Add these controlled repository helpers below the tests so loading behavior is deterministic without sleeps:

```swift
@MainActor
private final class ControlledRepository: WorkoutRepositoryProtocol {
    private let cached: WorkoutSnapshot
    private var refreshStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var refreshContinuation: CheckedContinuation<WorkoutSnapshot, Error>?

    init(cached: WorkoutSnapshot) { self.cached = cached }
    func cachedSnapshot() async throws -> WorkoutSnapshot { cached }
    func refresh() async throws -> WorkoutSnapshot {
        refreshStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        return try await withCheckedThrowingContinuation { refreshContinuation = $0 }
    }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot { cached }
    func waitUntilRefreshStarts() async {
        if refreshStarted { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
    func finishRefresh(with snapshot: WorkoutSnapshot) { refreshContinuation?.resume(returning: snapshot) }
}

private enum TestFailure: Error { case refresh }

@MainActor
private final class FailingRefreshRepository: WorkoutRepositoryProtocol {
    private let cached: WorkoutSnapshot
    init(cached: WorkoutSnapshot) { self.cached = cached }
    func cachedSnapshot() async throws -> WorkoutSnapshot { cached }
    func refresh() async throws -> WorkoutSnapshot { throw TestFailure.refresh }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot { cached }
}

@MainActor
private final class RecordingRepository: WorkoutRepositoryProtocol {
    private var snapshotValue: WorkoutSnapshot
    private(set) var toggledIDs: [String] = []
    init(snapshot: WorkoutSnapshot) { snapshotValue = snapshot }
    func cachedSnapshot() async throws -> WorkoutSnapshot { snapshotValue }
    func refresh() async throws -> WorkoutSnapshot { snapshotValue }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot {
        toggledIDs.append(workoutID)
        var overrides = snapshotValue.completionOverrides
        overrides[workoutID] = !snapshotValue.effectiveCompletion(for: workoutID)
        snapshotValue = WorkoutSnapshot(definitions: snapshotValue.definitions, completionOverrides: overrides)
        return snapshotValue
    }
}

private func makeViewModel(repository: any WorkoutRepositoryProtocol) -> TrainingCalendarViewModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    return TrainingCalendarViewModel(repository: repository, calendar: calendar, now: { now })
}

private func snapshot(offsets: [Int]) -> WorkoutSnapshot {
    let definitions = offsets.enumerated().map { index, offset in
        WorkoutDefinition(id: "workout-\(index)", name: "Workout \(index)", exerciseCount: index == 0 ? 1 : 2, weekdayOffset: offset, initiallyCompleted: false, sortOrder: index)
    }
    return WorkoutSnapshot(definitions: definitions, completionOverrides: [:])
}
```

Add these focused presentation and initial-error tests above the helpers:

```swift
@Test func preservesLongNameAndFormatsExerciseCounts() async {
    let longName = "Weekend Endurance and Conditioning Session"
    let definitions = [
        WorkoutDefinition(id: "one", name: longName, exerciseCount: 1, weekdayOffset: 5, initiallyCompleted: false, sortOrder: 0),
        WorkoutDefinition(id: "many", name: "Strength", exerciseCount: 12, weekdayOffset: 5, initiallyCompleted: false, sortOrder: 1)
    ]
    let repository = RecordingRepository(snapshot: WorkoutSnapshot(definitions: definitions, completionOverrides: [:]))
    let viewModel = makeViewModel(repository: repository)

    await viewModel.load()

    #expect(viewModel.days[5].workouts[0].name == longName)
    #expect(viewModel.days[5].workouts[0].exerciseCountText == "1 exercise")
    #expect(viewModel.days[5].workouts[1].exerciseCountText == "12 exercises")
    #expect(viewModel.days[5].workouts[0].statusText == nil)
}

@Test func exposesInitialErrorWhileKeepingSevenDates() async {
    let viewModel = makeViewModel(repository: FailingRefreshRepository(cached: .empty))

    await viewModel.load()

    #expect(viewModel.days.count == 7)
    #expect(viewModel.phase == .initialError("Unable to load workouts."))
}
```

- [ ] **Step 2: Run the view-model tests and verify compilation fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarTests/TrainingCalendarViewModelTests
```

Expected: compilation fails because presentation types and view model do not exist.

- [ ] **Step 3: Define immutable presentation state**

Create `TrainingCalendarViewState.swift`:

```swift
import Foundation

enum TrainingCalendarPhase: Equatable {
    case loading
    case loaded
    case initialError(String)
}

struct DayPresentation: Equatable, Identifiable {
    let id: Date
    let weekdayOffset: Int
    let date: Date
    let weekdayText: String
    let dayText: String
    let isToday: Bool
    let workouts: [WorkoutPresentation]
}

struct WorkoutPresentation: Equatable, Identifiable {
    let id: String
    let name: String
    let exerciseCountText: String
    let status: WorkoutDisplayStatus
    let statusText: String?
    let isCompleted: Bool
    let accessibilityLabel: String

    static let placeholder = WorkoutPresentation(
        id: "loading-placeholder",
        name: "Loading workout",
        exerciseCountText: "0 exercises",
        status: .future,
        statusText: nil,
        isCompleted: false,
        accessibilityLabel: "Loading workout"
    )
}
```

- [ ] **Step 4: Implement cache-first load, refresh, retry, and toggle**

Create `TrainingCalendarViewModel.swift` as an `@Observable @MainActor final class`. Use these exact stored properties and actions:

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TrainingCalendarViewModel {
    private(set) var days: [DayPresentation] = []
    private(set) var phase: TrainingCalendarPhase = .loading
    private(set) var isRefreshing = false
    private(set) var refreshErrorMessage: String?

    private let repository: any WorkoutRepositoryProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var loadTask: Task<Void, Never>?

    init(repository: any WorkoutRepositoryProtocol, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        days = makeDays(snapshot: .empty)
    }

    func load() async {
        if let loadTask { await loadTask.value; return }
        let task = Task { await performInitialLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    func retry() async { await refresh(hasVisibleContent: days.contains { !$0.workouts.isEmpty }) }

    func toggleCompletion(workoutID: String) async {
        do {
            let snapshot = try await repository.toggleCompletion(workoutID: workoutID)
            days = makeDays(snapshot: snapshot)
        } catch {
            refreshErrorMessage = "Unable to save completion. Please try again."
        }
    }

    private func performInitialLoad() async {
        days = makeDays(snapshot: .empty)
        phase = .loading
        var hasVisibleContent = false
        do {
            let cached = try await repository.cachedSnapshot()
            if !cached.definitions.isEmpty {
                days = makeDays(snapshot: cached)
                phase = .loaded
                hasVisibleContent = true
            }
        } catch {
            // Refresh below is the recovery path for an unreadable cache.
        }
        await refresh(hasVisibleContent: hasVisibleContent)
    }

    private func refresh(hasVisibleContent: Bool) async {
        isRefreshing = hasVisibleContent
        defer { isRefreshing = false }
        do {
            let refreshed = try await repository.refresh()
            days = makeDays(snapshot: refreshed)
            phase = .loaded
            refreshErrorMessage = nil
        } catch {
            if hasVisibleContent {
                phase = .loaded
                refreshErrorMessage = "Unable to refresh workouts."
            } else {
                phase = .initialError("Unable to load workouts.")
            }
        }
    }

    private func makeDays(snapshot: WorkoutSnapshot) -> [DayPresentation] {
        let currentDate = now()
        guard let week = try? CurrentWeekBuilder.days(containing: currentDate, calendar: calendar) else { return [] }
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = calendar.locale ?? .current
        weekdayFormatter.dateFormat = "EEE"
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = calendar.locale ?? .current
        dayFormatter.dateFormat = "d"

        return week.enumerated().map { offset, date in
            let workouts = snapshot.definitions
                .filter { $0.weekdayOffset == offset }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { definition in
                    let completed = snapshot.effectiveCompletion(for: definition.id)
                    let status = WorkoutStatusResolver.resolve(scheduledDate: date, today: currentDate, isCompleted: completed, calendar: calendar)
                    let countText = definition.exerciseCount == 1 ? "1 exercise" : "\(definition.exerciseCount) exercises"
                    let statusText = status.label
                    let accessibility = [definition.name, countText, statusText].compactMap { $0 }.joined(separator: ", ")
                    return WorkoutPresentation(id: definition.id, name: definition.name, exerciseCountText: countText, status: status, statusText: statusText, isCompleted: completed, accessibilityLabel: accessibility)
                }
            return DayPresentation(
                id: date,
                weekdayOffset: offset,
                date: date,
                weekdayText: weekdayFormatter.string(from: date),
                dayText: dayFormatter.string(from: date),
                isToday: calendar.isDate(date, inSameDayAs: currentDate),
                workouts: workouts
            )
        }
    }
}
```

- [ ] **Step 5: Run view-model tests and commit**

Run the Step 2 command. Expected: all selected tests pass with no timing-based waits.

```bash
git add TrainingCalendar/Features/TrainingCalendar/TrainingCalendarViewModel.swift TrainingCalendar/Features/TrainingCalendar/TrainingCalendarViewState.swift TrainingCalendarTests/TrainingCalendarViewModelTests.swift
git commit -m "feat: add cache-first training calendar view model"
```

---

### Task 5: Build the Figma-Aligned SwiftUI Calendar

**Files:**
- Create: `TrainingCalendar/DesignSystem/CalendarDesignTokens.swift`
- Create: `TrainingCalendar/Features/TrainingCalendar/WorkoutCardView.swift`
- Create: `TrainingCalendar/Features/TrainingCalendar/DayContainerView.swift`
- Create: `TrainingCalendar/Features/TrainingCalendar/TrainingCalendarScreen.swift`

**Interfaces:**
- Consumes: `DayPresentation`, `WorkoutPresentation`, and `TrainingCalendarViewModel`.
- Produces: the complete accessible current-week SwiftUI screen.

- [ ] **Step 1: Inspect the Figma node and record measured tokens**

Open node `23776:49540` in Figma Inspect mode. Record the actual light-mode colors, type styles, horizontal margins, day/card spacing, padding, radii, border/shadow values, and icon dimensions in `CalendarDesignTokens.swift` using semantic names:

```swift
import SwiftUI

enum CalendarDesignTokens {
    static let screenHorizontalPadding: CGFloat = 16
    static let daySpacing: CGFloat = 12
    static let workoutSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 8
    static let brandPurple = Color(red: 0.42, green: 0.25, blue: 0.88)
    static let assignedBackground = Color(uiColor: .secondarySystemBackground)
    static let missedBackground = Color(red: 1.00, green: 0.94, blue: 0.94)
    static let completedBackground = Color(red: 0.92, green: 0.97, blue: 0.94)
    static let futureBackground = Color(uiColor: .systemGray6)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let checkmarkSize: CGFloat = 20
}
```

These values are the complete baseline derived from the available Figma preview. If authenticated Inspect access exposes different measurements, update only this token file during the same visual-review step and record the final values in the commit diff.

- [ ] **Step 2: Implement the accessible workout card**

Create `WorkoutCardView.swift`:

```swift
import SwiftUI

struct WorkoutCardView: View {
    let workout: WorkoutPresentation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(workout.exerciseCountText)
                        .font(.subheadline)
                        .foregroundStyle(CalendarDesignTokens.secondaryText)
                    if let statusText = workout.statusText {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                    }
                }
                Spacer(minLength: 8)
                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: CalendarDesignTokens.checkmarkSize))
                        .foregroundStyle(CalendarDesignTokens.brandPurple)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(CalendarDesignTokens.cardPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CalendarDesignTokens.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-\(workout.id)")
        .accessibilityLabel(workout.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var backgroundColor: Color {
        switch workout.status {
        case .missed: CalendarDesignTokens.missedBackground
        case .assigned: CalendarDesignTokens.assignedBackground
        case .completed: CalendarDesignTokens.completedBackground
        case .future: CalendarDesignTokens.futureBackground
        }
    }
}
```

- [ ] **Step 3: Implement stable day containers and loading placeholders**

Create `DayContainerView.swift` with a date header at the upper left and a workout `VStack`. Give each container `day-<weekdayOffset>` as its accessibility identifier. Highlight only the numeric day for today. Add a `redacted(reason: .placeholder)` workout-shaped placeholder when `isLoading` is true and workouts are empty:

```swift
import SwiftUI

struct DayContainerView: View {
    let day: DayPresentation
    let isLoading: Bool
    let onWorkoutTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CalendarDesignTokens.workoutSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekdayText)
                Text(day.dayText)
                    .foregroundStyle(day.isToday ? CalendarDesignTokens.brandPurple : .primary)
                    .fontWeight(day.isToday ? .bold : .regular)
            }
            ForEach(day.workouts) { workout in
                WorkoutCardView(workout: workout) { onWorkoutTap(workout.id) }
            }
            if isLoading && day.workouts.isEmpty {
                WorkoutCardView(workout: .placeholder, onTap: {})
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("day-\(day.weekdayOffset)")
        .accessibilityElement(children: .contain)
    }
}
```

- [ ] **Step 4: Assemble screen, cached refresh, and retry states**

Create `TrainingCalendarScreen.swift`:

```swift
import SwiftUI

struct TrainingCalendarScreen: View {
    @State var viewModel: TrainingCalendarViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CalendarDesignTokens.daySpacing) {
                    ForEach(viewModel.days) { day in
                        DayContainerView(
                            day: day,
                            isLoading: viewModel.phase == .loading,
                            onWorkoutTap: { id in Task { await viewModel.toggleCompletion(workoutID: id) } }
                        )
                    }
                    if case .initialError(let message) = viewModel.phase {
                        errorView(message)
                    } else if let message = viewModel.refreshErrorMessage {
                        errorView(message)
                    }
                }
                .padding(.horizontal, CalendarDesignTokens.screenHorizontalPadding)
            }
            .navigationTitle("Training Calendar")
            .overlay(alignment: .topTrailing) {
                if viewModel.isRefreshing { ProgressView().padding() }
            }
        }
        .task { await viewModel.load() }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text(message).font(.footnote)
            Button("Retry") { Task { await viewModel.retry() } }
        }
        .accessibilityIdentifier("calendar-error")
    }
}
```

Refine the hierarchy against Figma at iPhone 17 Pro width and at an iPhone SE-sized width. Verify long names truncate, Dynamic Type does not hide status/count, future cards remain tappable, and no state removes the seven date headers.

- [ ] **Step 5: Build and commit the SwiftUI feature**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **` with no warnings introduced by the new views.

```bash
git add TrainingCalendar/DesignSystem TrainingCalendar/Features/TrainingCalendar
git commit -m "feat: build accessible weekly calendar UI"
```

---

### Task 6: Wire Production Dependencies and Remove the Template App

**Files:**
- Modify: `TrainingCalendar/TrainingCalendarApp.swift`
- Delete: `TrainingCalendar/ContentView.swift`
- Delete: `TrainingCalendar/Item.swift`
- Delete: `TrainingCalendarTests/TrainingCalendarTests.swift`

**Interfaces:**
- Consumes: `CachedWorkout`, `WorkoutCompletionOverride`, `BundledWorkoutFixtureSource`, `SwiftDataWorkoutRepository`, and `TrainingCalendarViewModel`.
- Produces: a launchable production app and deterministic UI-test launch mode.

- [ ] **Step 1: Replace the template model container and root view**

Move the app file to `TrainingCalendar/App/TrainingCalendarApp.swift` and implement:

```swift
import SwiftData
import SwiftUI

@main
struct TrainingCalendarApp: App {
    private let container: ModelContainer
    private let viewModel: TrainingCalendarViewModel

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            let modelContainer = try ModelContainer(for: CachedWorkout.self, WorkoutCompletionOverride.self, configurations: configuration)
            let source = try BundledWorkoutFixtureSource(bundle: .main)
            let repository = SwiftDataWorkoutRepository(context: modelContainer.mainContext, source: source)
            if isUITesting && ProcessInfo.processInfo.arguments.contains("-reset-store") {
                try modelContainer.mainContext.delete(model: CachedWorkout.self)
                try modelContainer.mainContext.delete(model: WorkoutCompletionOverride.self)
                try modelContainer.mainContext.save()
            }
            container = modelContainer
            viewModel = TrainingCalendarViewModel(repository: repository)
        } catch {
            fatalError("Unable to configure Training Calendar: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TrainingCalendarScreen(viewModel: viewModel)
        }
        .modelContainer(container)
    }
}
```

Keep UI-test storage persistent so the relaunch test proves completion persistence; use `-reset-store` only on the first launch of a test.

- [ ] **Step 2: Delete the starter files and run the complete unit suite**

Delete `ContentView.swift`, `Item.swift`, and the placeholder `TrainingCalendarTests.swift` using a recoverable file deletion through the IDE or trash.

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarTests
```

Expected: all domain, fixture, repository, and view-model tests pass.

- [ ] **Step 3: Launch and manually verify the primary states**

Run the app from Xcode on iPhone 17 Pro. Confirm seven current dates, two workouts on Monday and Wednesday, empty Thursday and Sunday, long Saturday-name truncation, current-day highlight, correct statuses, future tapping, completed checkmark, and persistence after terminating and relaunching the app.

- [ ] **Step 4: Commit application wiring**

```bash
git add -A TrainingCalendar TrainingCalendarTests
git commit -m "feat: wire persisted training calendar app"
```

---

### Task 7: Add the End-to-End UI Test

**Files:**
- Modify: `TrainingCalendarUITests/TrainingCalendarUITests.swift`
- Delete: `TrainingCalendarUITests/TrainingCalendarUITestsLaunchTests.swift`

**Interfaces:**
- Consumes: accessibility identifiers `day-0` through `day-6`, `workout-<id>`, and accessibility labels produced by the app.
- Produces: one deterministic launch, interaction, and relaunch persistence test.

- [ ] **Step 1: Write the UI test against the required accessibility contract**

Replace the generated UI test with:

```swift
import XCTest

final class TrainingCalendarUITests: XCTestCase {
    func testCurrentWeekMultipleWorkoutsAndCompletionPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-store"]
        app.launch()

        for offset in 0...6 {
            XCTAssertTrue(app.otherElements["day-\(offset)"].waitForExistence(timeout: 3))
        }
        XCTAssertTrue(app.buttons["workout-monday-upper-body"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["workout-monday-core-mobility"].exists)

        let workout = app.buttons["workout-tuesday-cardio"]
        XCTAssertTrue(workout.waitForExistence(timeout: 3))
        workout.tap()
        XCTAssertTrue(workout.label.contains("Completed"))

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let persistedWorkout = app.buttons["workout-tuesday-cardio"]
        XCTAssertTrue(persistedWorkout.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedWorkout.label.contains("Completed"))
    }
}
```

Delete the generated launch-performance test because it does not validate assignment behavior.

- [ ] **Step 2: Run the UI test**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:TrainingCalendarUITests/TrainingCalendarUITests/testCurrentWeekMultipleWorkoutsAndCompletionPersistsAfterRelaunch
```

Expected: the test passes across initial launch and relaunch using the identifiers already defined on `DayContainerView` and `WorkoutCardView`.

- [ ] **Step 3: Run all tests and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: all unit and UI tests pass.

```bash
git add TrainingCalendar TrainingCalendarUITests
git commit -m "test: cover weekly calendar completion flow"
```

---

### Task 8: Complete Submission Documentation and Final Verification

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: final architecture, test commands, AI collaboration history, and video URL supplied before submission.
- Produces: reviewer-facing build, architecture, workflow, AI, and walkthrough documentation.

- [ ] **Step 1: Write the README with the required sections**

Create `README.md` with these headings and concrete content:

```markdown
# Training Calendar

A SwiftUI implementation of Everfit's current-week training calendar assignment.

## Requirements

- Xcode 26.6 or compatible
- iOS 17 or later

## Build and Run

1. Open `TrainingCalendar.xcodeproj`.
2. Select the `TrainingCalendar` scheme and an iOS simulator.
3. Run with Command-R.

## Architecture

The app uses lean MVVM. Pure domain services calculate Monday-through-Sunday dates and workout statuses. `TrainingCalendarViewModel` creates immutable screen presentation values. `SwiftDataWorkoutRepository` loads cached definitions immediately, refreshes from bundled JSON, and stores explicit completion overrides separately by workout ID.

## Data and Caching

`workouts.json` uses relative weekday offsets so the sample remains in the current week. To change sample content, preserve unique IDs and use offsets 0 through 6. On launch, cached data appears first, then the bundle is decoded and atomically replaces cached definitions. Local completion and uncompletion overrides survive refresh and relaunch.

## Testing

Run the full suite with:

`xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## AI Collaboration

Tools used: OpenAI Codex for requirement analysis, architecture exploration, implementation planning, and test-case review.

Representative prompts:

1. “Analyze the mobile test guide and turn the current-week, status, cache, and completion requirements into an implementation-ready SwiftUI specification.”
2. “Design cache-refresh semantics that preserve both marking and unmarking by workout ID when fixture definitions are refreshed.”
3. “Create deterministic tests for Monday-first date math, status precedence, cache-first loading, and persisted completion without timing-based sleeps.”

All generated code was reviewed, adapted to project constraints, and must be explainable during the walkthrough.

## Delivery Workflow

The feature process is: clarify requirements and exclusions; inspect design and existing code; agree on architecture and acceptance criteria; implement in test-backed increments; compare UI against Figma; run automated and accessibility checks; conduct code review; release through a reviewed repository change; monitor feedback and regressions.

## Video Walkthrough

Before repository submission, add the recorded three-to-five-minute walkthrough URL here. The recording demonstrates the app, architecture, data flow, cache behavior, persistence, test coverage, and AI-assisted decisions.
```

Replace the final video instruction with the actual URL immediately after recording; do not publish the repository with instructional copy in place of the link.

- [ ] **Step 2: Perform final automated verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild clean test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: clean build, all unit tests pass, and the end-to-end UI test passes.

- [ ] **Step 3: Perform final manual and submission checks**

Compare the running app side by side with Figma at iPhone 17 Pro width. Check loading, cache refresh, empty days, all four statuses, toggle/unmark, relaunch persistence, long-name truncation, largest accessibility text size, VoiceOver reading order, and light/dark appearance when represented by Figma. Record the walkthrough, insert its URL, and confirm build steps work from a clean clone before making the repository public.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md
git commit -m "docs: add build and submission guide"
git status --short
```

Expected: the commit succeeds and `git status --short` prints no entries.

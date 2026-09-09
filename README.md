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

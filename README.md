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

The app uses lean MVVM. Pure domain services calculate Monday-through-Sunday dates and workout statuses. `TrainingCalendarViewModel` creates immutable screen presentation values. `SwiftDataWorkoutRepository` loads cached definitions immediately, refreshes from the supplied Everfit mock API, and stores explicit completion overrides separately by workout ID.

## Data and Caching

The app requests `https://thinhleeverfit.github.io/everfit-ios-test-mock-api/workouts.json`. It maps each API `day` value to the Monday-first weekday offset and flattens that day's assignments in API order. Assignment status `2` is initially completed; statuses `0` and `1` are initially incomplete. On launch, cached data appears first, then the response is decoded and atomically replaces cached definitions. Local completion and uncompletion overrides survive refresh and relaunch.

## Testing

Run the unit-test suite with:

`xcodebuild test -project TrainingCalendar.xcodeproj -scheme TrainingCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## AI Collaboration

OpenAI Codex coordinated the work across these stages and models:

| Stage | Model |
| --- | --- |
| Requirements analysis, brainstorming, specification, and implementation planning | OpenAI Codex / GPT-6 |
| Feature implementation and corrective changes | GPT-5.6 Terra subagents |
| Consolidated code review and fix verification | GPT-6 Astra |
| Documentation updates | OpenAI Codex / GPT-5 |

Subagent changes were reviewed and verified by the primary Codex agent before completion.

Representative prompts:

1. “Analyze the mobile test guide and turn the current-week, status, cache, and completion requirements into an implementation-ready SwiftUI specification.”
2. “Design cache-refresh semantics that preserve both marking and unmarking by workout ID when fixture definitions are refreshed.”
3. “Create deterministic tests for Monday-first date math, status precedence, cache-first loading, and persisted completion without timing-based sleeps.”

All generated code was reviewed, adapted to project constraints, and must be explainable during the walkthrough.

## Delivery Workflow

The feature process is: clarify requirements and exclusions; inspect design and existing code; agree on architecture and acceptance criteria; implement in test-backed increments; compare UI against Figma; run automated and accessibility checks; conduct code review; release through a reviewed repository change; monitor feedback and regressions.

## Video Walkthrough

https://drive.google.com/file/d/1Mf8v16R-GQs-RLbyGc-7SgHnqUZr11b2/view?usp=sharing

# Training Calendar Design Specification

**Status:** Approved design ready for implementation planning  
**Platform:** iOS 17 or later  
**UI framework:** SwiftUI  
**Persistence:** SwiftData  
**Concurrency:** Swift Concurrency (`async`/`await`)  
**Dependencies:** Apple frameworks only

## Purpose

Build a focused mobile training calendar that demonstrates accurate SwiftUI implementation, clear architecture, deterministic date behavior, cache-first loading, and local workout completion. The deliverable is scoped for a 24-hour hiring exercise and covers the required behavior from `Everfit_Mobile_Test Guide.pdf`.

The app displays the current Monday-through-Sunday week only. It asynchronously loads workout definitions from the supplied Everfit mock API and maps them into the calendar's Monday-first model.

## Goals

- Always show all seven dates for the current week, ordered Monday through Sunday.
- Display zero or more workouts for each day.
- Show workout name, exercise count, date-derived status, and completed checkmark.
- Toggle any workout between completed and incomplete using its stable ID.
- Persist both workout data and local completion overrides across launches.
- Load cached content immediately, then refresh it asynchronously from the Everfit mock API.
- Match the linked Figma node for visual tokens and presentation details.
- Keep date, status, repository, and view logic independently testable.
- Include the documentation and walkthrough guidance required for submission.

## Non-goals

- Previous-week or next-week navigation.
- Synchronization with a production remote server.
- Workout detail, editing, creation, deletion, or exercise-level interactions.
- Authentication, user profiles, notifications, analytics, or background refresh.
- Third-party libraries.
- Artificial loading delays in production.

## User Experience

### Screen structure

`TrainingCalendarScreen` presents a vertically scrolling current-week view designed for phone widths. It contains seven stable day containers. Each container shows:

- A weekday abbreviation at the upper left, using `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, or `Sun`.
- The numeric day of the month directly below the weekday.
- A vertical stack of zero or more workout cards.

Today's date uses the purple highlight from the Figma design. Empty days retain their date header and reserved container structure without fabricated workout content or an unnecessary empty-state message.

Workout cards show:

- The workout name on one line with trailing ellipsis truncation.
- The exercise count with `1 exercise` or `<n> exercises` copy.
- A status label when the status calls for text.
- A trailing checkmark when completed.

The complete card is one tap target. Every non-empty workout card, including a future workout, toggles completion locally.

### Visual rules

The Figma node at `23776:49540` is the source of truth for colors, typography, spacing, card size, corner radius, borders, and icons. Implementation must define these values as named SwiftUI design tokens rather than repeat literals across views. The public Figma preview confirms the mobile design set but does not expose sufficiently accurate measurements, so values must be inspected in Figma during implementation.

Semantic tokens must cover:

- Brand purple and today's date treatment.
- Normal, missed, completed, and inactive-future card backgrounds.
- Primary, secondary, status, and disabled text colors.
- Card border or shadow treatment.
- Week and card spacing, padding, and corner radii.

### Accessibility

- Each workout card has a minimum 44-by-44-point hit area.
- Text supports Dynamic Type without clipping essential status or count information.
- A workout exposes one VoiceOver element containing its name, exercise count, date, and effective status.
- The checkmark has a meaningful accessibility label and is not announced twice through decorative icon content.
- Status does not depend on color alone; text or the completed checkmark communicates the state.

## Workout Status Rules

Effective completion is resolved before the date-derived state. A local completion override takes priority over the fixture's initial value, including an explicit local `false` value created by unmarking a fixture-completed workout.

| Condition | Status text | Checkmark | Interaction | Presentation |
|---|---|---:|---|---|
| Effective completion is `true` | Completed | Yes | Toggles to incomplete | Completed colors from Figma |
| Incomplete and scheduled before today | Missed | No | Toggles to complete | Missed colors from Figma |
| Incomplete and scheduled today | Assigned | No | Toggles to complete | Assigned colors from Figma |
| Incomplete and scheduled after today | None | No | Toggles to complete | Greyed future colors from Figma |

All day comparisons use the user's current Calendar and time zone after normalizing dates to the start of day. Locale affects display text but never changes Monday as the first day of this feature's week.

## Remote API Contract

The production source is `https://thinhleeverfit.github.io/everfit-ios-test-mock-api/workouts.json`. It returns a `data` array of weekday records, each with a `day` offset and its `assignments`:

```json
{
  "data": [{
    "day": 0,
    "assignments": [{
      "_id": "monday-upper-body",
      "title": "Upper Body Strength",
      "total_exercise": 8,
      "status": 1
    }]
  }]
}
```

Field rules:

- `day` is an integer from `0` through `6`, where `0` is Monday.
- `_id` is a non-empty unique workout identifier and remains stable across refreshes.
- `title` is a non-empty display string.
- `total_exercise` is an integer greater than or equal to zero.
- Assignment `status` `2` maps to initially completed; every other status maps to initially incomplete until a local override exists.

The decoder rejects a response as a whole if JSON is malformed, an HTTP response is not successful, IDs are duplicated, or any mapped field violates the contract. It does not partially replace a valid cache with incomplete data.

## Architecture

### Presentation

`TrainingCalendarScreen` observes one `@MainActor` `TrainingCalendarViewModel`. Small SwiftUI components keep layout responsibilities focused:

- `WeekCalendarView` renders the ordered collection of seven day presentations.
- `DayContainerView` renders one date header and its workout stack.
- `WorkoutCardView` renders one workout's content and sends its ID through a tap closure.
- `WorkoutCardStyle` maps semantic presentation state to Figma-backed design tokens.

Views receive immutable presentation values and closures. They do not query SwiftData, decode JSON, perform calendar math, or determine statuses.

### View model

`TrainingCalendarViewModel` owns the screen state and coordinates repository operations. It exposes:

- Seven ordered day presentation values immediately after startup.
- A phase representing initial loading, loaded content, or an initial-load error.
- A separate refresh-error value so cached content remains usable when refresh fails.
- An `isRefreshing` value that does not replace already displayed content.
- An asynchronous `load()` operation.
- An asynchronous `toggleCompletion(workoutID:)` operation.

The view model groups records by weekday offset, resolves effective completion, derives display status, and updates the affected presentation immediately after a successful persisted toggle.

### Domain services

`CurrentWeekBuilder` is a pure service that creates exactly seven dates beginning on Monday. It accepts a Calendar and a current Date so tests do not depend on wall-clock time.

`WorkoutStatusResolver` is a pure service that accepts a scheduled date, today's normalized date, and effective completion value. It returns `missed`, `assigned`, `completed`, or `future` according to the status table.

### Data layer

`WorkoutRepository` separates the presentation layer from fixture and persistence details. Its responsibilities are:

- Return cached workout definitions and completion overrides.
- Refresh definitions from an asynchronous `WorkoutFixtureSource`.
- Atomically replace cached definitions after successful validation.
- Preserve all local completion overrides whose workout IDs still exist.
- Remove cached definitions and overrides for IDs removed from the refreshed fixture.
- Persist an explicit Boolean completion override for each toggle.

`RemoteWorkoutFixtureSource` requests, decodes, and validates the API response asynchronously. Tests replace it with controlled sources that return records, suspend loading, or throw errors.

SwiftData stores two model types:

- `CachedWorkout`: stable ID, name, exercise count, weekday offset, initial completion value, and refresh timestamp.
- `WorkoutCompletionOverride`: unique workout ID, explicit completion value, and modification timestamp.

Separating the override from the definition ensures a locally unmarked `false` remains authoritative when refreshed fixture data says `true`.

## Data Flow

1. The screen creates the view model and starts `load()` once.
2. The view model calculates the current Monday-through-Sunday dates immediately.
3. The repository reads SwiftData. Cached records appear without waiting for fixture decoding.
4. The repository starts an asynchronous remote API refresh.
5. The source decodes and validates every API assignment.
6. The repository replaces cached definitions in one persistence transaction and retains applicable local overrides.
7. The view model rebuilds seven day presentations from refreshed records.
8. When a card is tapped, the view model asks the repository to persist the inverse of its current effective completion.
9. After persistence succeeds, the affected card is rebuilt with its new status and checkmark.

Loading must be idempotent. Repeated SwiftUI lifecycle events must not launch concurrent duplicate refreshes.

## Loading and Error Behavior

All seven date headers are visible during every state.

- **No cache, refresh in progress:** workout regions show Figma-aligned placeholders while date headers remain final and stable.
- **Cache available, refresh in progress:** cached workouts remain visible; refresh uses a subtle progress treatment that does not block interaction.
- **Refresh succeeds:** refreshed definitions replace cached definitions without an empty-state flash.
- **Refresh fails with cache:** cached content stays visible with a compact error message and retry action.
- **Refresh fails without cache:** each date remains visible and the workout region presents an inline error with retry.
- **Toggle persistence fails:** restore the prior visible state and present a non-blocking error. Never show a completion state that was not persisted.

Because the production source is remote, failures can result from connectivity, an unsuccessful HTTP response, or invalid response data. Error behavior remains specified and testable through dependency injection.

## Testing Strategy

Unit tests cover:

- Monday-through-Sunday generation in a normal week and across month and year boundaries.
- Monday anchoring under a locale whose default first weekday is Sunday.
- Start-of-day comparison around daylight-saving transitions using a fixed Calendar and time zone.
- Every status-table branch and completed-state precedence.
- Zero, one, and multiple workouts grouped into the correct weekday.
- Singular and plural exercise-count formatting.
- Remote-response validation for malformed JSON, HTTP failures, duplicate IDs, invalid offsets, empty names, and negative counts.
- Cache-first results followed by remote refresh results.
- Preservation of explicit `true` and `false` completion overrides during refresh.
- Removal of stale records and their overrides.
- Toggle-by-ID persistence and restoration after recreating the repository and view model.
- Initial-loading, cached-refresh, initial-error, and cached-error presentation states.

One focused UI test launches with deterministic remote-source and clock dependencies, verifies all seven date headers, confirms two workouts appear in one day, taps a workout, observes its checkmark and Completed status, and relaunches to confirm persistence.

Snapshot tests are optional and should be added only if the project already has a reliable snapshot setup. Manual comparison against Figma remains required for pixel-level visual review, Dynamic Type, dark/light appearance if represented in the design, and common phone widths.

## Acceptance Criteria

The feature is complete when:

- The app builds and launches on an iOS 17-or-later simulator.
- The current week contains exactly seven ordered Monday-through-Sunday day containers.
- Today's numeric date has the Figma purple highlight.
- API workouts appear on their mapped current-week days, including multiple workouts in one day and empty days.
- Long names truncate with an ellipsis.
- Every workout displays its exercise count.
- Past incomplete, today incomplete, future incomplete, and completed workouts follow the status table.
- Every workout toggles by stable ID, including future workouts.
- Completed workouts display a trailing checkmark.
- Completion and explicit uncompletion survive app relaunch.
- Cached content appears before the asynchronous remote refresh completes.
- Loading and error states retain all seven correct dates.
- Automated tests for domain, repository, view-model, and primary UI behavior pass.
- Visual inspection confirms conformance to the Figma node.

## Submission Documentation

`README.md` must contain:

- Supported Xcode and iOS versions plus build and run steps.
- A concise architecture and data-flow explanation.
- The cache-first refresh and local-override rules.
- The mock API URL and its field-mapping rules.
- An **AI Collaboration** section naming the tools used and including two or three substantive prompts from the work, such as date/status modeling, cache merge behavior, and test design.
- A link to the mandatory three-to-five-minute walkthrough video before submission.
- A short description of the end-to-end feature workflow: requirement review, clarification, design, implementation, testing, review, release, and monitoring.

The walkthrough must demonstrate the current week, multiple workouts in a day, each status treatment, completion toggling, persisted completion after relaunch, architecture, data flow, caching, testing, and how AI accelerated the work while leaving the candidate able to explain every code path.

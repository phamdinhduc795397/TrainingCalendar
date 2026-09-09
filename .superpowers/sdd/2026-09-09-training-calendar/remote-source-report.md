# Remote fixture source

The app now uses `RemoteWorkoutFixtureSource` for production refreshes from:

`https://thinhleeverfit.github.io/everfit-ios-test-mock-api/workouts.json`

The source validates successful HTTP responses, decodes the API `data` envelope, and flattens each day's assignments in response order. API `day` is retained as the Monday-first weekday offset. Assignment status `2` maps to `initiallyCompleted == true`; status `0` and `1` map to `false`. Existing shared validation still rejects duplicate or empty IDs, blank names, negative exercise counts, and invalid weekday values.

The cache-first repository and its error behavior are unchanged. HTTPS requires no ATS exception or entitlement.

Validation completed:

- `RemoteWorkoutFixtureSourceTests`: 4 passed.
- Generic iOS Simulator build: succeeded.

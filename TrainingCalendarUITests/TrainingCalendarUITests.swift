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

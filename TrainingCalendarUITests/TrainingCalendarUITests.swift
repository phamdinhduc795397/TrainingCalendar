import XCTest

final class TrainingCalendarUITests: XCTestCase {
    func testCurrentWeekMultipleWorkoutsAndCompletionPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-store"]
        app.launch()

        XCTAssertTrue(app.otherElements["day-0"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["day-date-0"].label, "7")
        XCTAssertTrue(app.buttons["workout-monday-upper-body"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["workout-monday-core-mobility"].exists)

        let workout = app.buttons["workout-tuesday-cardio"]
        scrollUntilHittable(workout, in: app)
        workout.tap()
        waitForCompletedLabel(on: workout)

        scrollUntilHittable(app.staticTexts["day-date-6"], in: app)
        XCTAssertEqual(app.staticTexts["day-date-6"].label, "13")

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let persistedWorkout = app.buttons["workout-tuesday-cardio"]
        scrollUntilHittable(persistedWorkout, in: app)
        waitForCompletedLabel(on: persistedWorkout)
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 1), element.isHittable {
                return
            }
            app.swipeUp()
        }
        XCTFail("Expected \(element) to become hittable after scrolling.", file: file, line: line)
    }

    private func waitForCompletedLabel(
        on element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Completed"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed, file: file, line: line)
    }
}

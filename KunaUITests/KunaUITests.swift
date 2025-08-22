import XCTest

final class KunaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    override func tearDownWithError() throws { }

    // MARK: - Test

    @MainActor
    func testGenerateScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        let projectName = "Marketing Website"
        let detailTask  = "Fix 404s"

        // 01 — App launch
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        snapshot("01-AppLaunch")

        // Login if needed
        loginIfNeeded(app)

        // Ensure we’re on Projects
        ensureOnProjects(app)

        // Open the project we want to showcase
        openProject(named: projectName, in: app)

        // Wait until the task list is visible (use a known task)
        XCTAssertTrue(waitForTask(named: detailTask, in: app, timeout: 10),
                      "Didn't enter \(projectName) task list")
        snapshot("02-TaskList")

        // Task list screen doesn't expose the sidebar → go back to Projects
        tapBack(app)
        ensureOnProjects(app)

        // --- Labels via sidebar ---
        openSidebar(app)
        tapSidebarItem("labels", app: app)
        XCTAssertTrue(app.staticTexts["Labels"].waitForExistence(timeout: 8))
        snapshot("03-LabelsView")

        // --- Back to Projects → project → open specific task ---
        openSidebar(app)      // sidebar available on Labels
        tapSidebarItem("projects", app: app)
        ensureOnProjects(app)

        openProject(named: projectName, in: app)
        XCTAssertTrue(waitForTask(named: detailTask, in: app, timeout: 10))

        // Open the specific task
        openTask(named: detailTask, in: app)

        // Ensure Task Details is shown
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 8), "Task details screen didn't appear")
        snapshot("04-TaskDetails")

        // --- Related Tasks screen ---
        openRow(titled: "Related Tasks", in: app)
        XCTAssertTrue(waitForNavTitle("Related Tasks", in: app, timeout: 6),
                      "Related Tasks screen didn’t appear")
        snapshot("05-RelatedTasks")

        // Close Related Tasks via Done
        tapNavButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4), "Did not return to Task Details after Done")

        // --- Comments screen ---
        openRow(titled: "Comments", in: app)
        XCTAssertTrue(waitForNavTitle("Comments", in: app, timeout: 6),
                      "Comments screen didn’t appear")
        snapshot("06-Comments")

        // --- NEW: Settings → Display Options ---
        // Leave Comments back to Task Details
        tapNavButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4),
                      "Did not return to Task Details after leaving Comments")

        // Back out to the task list, then Projects (to ensure we’re on a screen that exposes the sidebar)
        tapBack(app) // Task Details -> Task List
        tapBack(app) // Task List -> Projects
        ensureOnProjects(app)

        // Open Settings from the sidebar
        openSidebar(app)
        tapSidebarItem("settings", app: app) // will also fall back to visible "Settings" label
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8),
                      "Settings screen didn’t appear")

        // Open the Display Options row (scrolls if needed)
        openRow(titled: "Display Options", in: app)

        // Wait for the Display Options screen (SwiftUI small/large title tolerant)
        XCTAssertTrue(waitForNavTitle("Display Options", in: app, timeout: 6),
                      "Display Options screen didn’t appear")

        // Capture the screenshot
        snapshot("07-DisplayOptions")

        // AX dump on teardown for easier triage later
        addTeardownBlock {
            let dump = app.debugDescription
            let att = XCTAttachment(string: dump)
            att.lifetime = .keepAlways
            self.add(att)
        }
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Sidebar / Login helpers

    /// Opens the sidebar via MenuButton if present, otherwise performs a true left-edge drag.
    /// NOTE: Only call this on screens that actually expose the menu (Projects, Labels, Favorites).
    private func openSidebar(_ app: XCUIApplication) {
        if app.buttons["MenuButton"].waitForExistence(timeout: 1.5) {
            app.buttons["MenuButton"].tap()
            return
        }
        // Fallback: left-edge drag to satisfy your DragGesture(start.x < 20)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        // Prove openness by an item becoming hittable
        let opened =
            app.buttons["Sidebar.labels"].waitForHittable(timeout: 2) ||
            app.buttons["Sidebar.projects"].waitForHittable(timeout: 2) ||
            app.buttons["Sidebar.settings"].waitForHittable(timeout: 2) ||
            app.buttons["Labels"].waitForHittable(timeout: 2) ||
            app.buttons["Projects"].waitForHittable(timeout: 2) ||
            app.buttons["Settings"].waitForHittable(timeout: 2)
        XCTAssertTrue(opened, "Sidebar did not appear (this screen may not expose it)")
    }

    /// Taps a sidebar item by **identifier** first (e.g. Sidebar.labels / Sidebar.projects),
    /// falling back to its visible label ("Labels" / "Projects").
    private func tapSidebarItem(_ itemKey: String, app: XCUIApplication) {
        let id = "Sidebar.\(itemKey)"        // e.g. "labels", "projects", "settings"
        let labelFallback = itemKey.capitalized
        let button: XCUIElement = {
            if app.buttons[id].exists { return app.buttons[id] }
            if app.buttons[labelFallback].exists { return app.buttons[labelFallback] }
            return app.buttons.firstMatch
        }()
        tapWhenHittableOrCoordinate(button, timeout: 4, failureMessage: "Sidebar item \(itemKey) not hittable")
    }

    /// Ensures we're on the Projects screen (waits for its title text somewhere on screen).
    private func ensureOnProjects(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Projects"].waitForExistence(timeout: 8), "Projects screen didn’t appear")
    }

    /// Logs in only if the login fields are present.
    private func loginIfNeeded(_ app: XCUIApplication) {
        let serverField = app.textFields.element(boundBy: 0)
        guard serverField.exists else { return }

        let usernameField = app.textFields["Username"]
        let passwordField = app.secureTextFields["Password"]
        let loginButton   = app.buttons["Log In"]

        let serverURL = ProcessInfo.processInfo.environment["VIKUNJA_SERVER_URL"] ?? "https://demo.vikunja.io"
        let username  = ProcessInfo.processInfo.environment["VIKUNJA_USERNAME"] ?? "demo"
        let password  = ProcessInfo.processInfo.environment["VIKUNJA_PASSWORD"] ?? "demo"

        serverField.tap()
        serverField.typeText(serverURL)

        if usernameField.waitForExistence(timeout: 2) {
            usernameField.tap()
            usernameField.typeText(username)
        }
        if passwordField.waitForExistence(timeout: 2) {
            passwordField.tap()
            passwordField.typeText(password)
        }
        if loginButton.waitForExistence(timeout: 2) {
            loginButton.tap()
        }

        ensureOnProjects(app)
    }

    // MARK: - Container-agnostic navigation

    /// Opens a project by visible title. Works with List/ScrollView/CollectionView.
    private func openProject(named name: String, in app: XCUIApplication) {
        // Direct if visible
        if app.cells.staticTexts[name].exists && app.cells.staticTexts[name].isHittable {
            app.cells.staticTexts[name].tap(); return
        }
        if app.staticTexts[name].exists && app.staticTexts[name].isHittable {
            app.staticTexts[name].tap(); return
        }

        let containers = scrollableContainers(in: app)
        let target = app.staticTexts[name]
        scrollToElement(target, containers: containers, maxSwipes: 12)
        XCTAssertTrue(target.exists, "Project '\(name)' not found")

        // Prefer tapping the cell that contains the label
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if cell.exists { cell.tap() } else { target.tap() }
    }

    /// Opens a task by its visible title within the current task list.
    private func openTask(named name: String, in app: XCUIApplication) {
        // Prefer tapping the cell containing the text
        var cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if cell.exists && cell.isHittable { cell.tap(); return }

        let label = app.staticTexts[name]
        if label.exists && label.isHittable { label.tap(); return }

        // Scroll to reveal
        let containers = scrollableContainers(in: app)
        for _ in 0..<12 {
            cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.exists && cell.isHittable { cell.tap(); return }
            if label.exists && label.isHittable { label.tap(); return }
            for c in containers where c.exists && c.isHittable { c.swipeUp() }
        }

        XCTAssertTrue(cell.exists || label.exists, "Task '\(name)' not found in the task list")
        let target = cell.exists ? cell : label
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Taps a row/cell by its main text, scrolling if needed.
    private func openRow(titled title: String, in app: XCUIApplication) {
        if app.staticTexts[title].exists && app.staticTexts[title].isHittable {
            app.staticTexts[title].tap(); return
        }
        var rowCell = app.cells.containing(.staticText, identifier: title).firstMatch
        if rowCell.exists && rowCell.isHittable { rowCell.tap(); return }

        let containers = scrollableContainers(in: app)
        for _ in 0..<10 {
            if app.staticTexts[title].exists && app.staticTexts[title].isHittable { app.staticTexts[title].tap(); return }
            rowCell = app.cells.containing(.staticText, identifier: title).firstMatch
            if rowCell.exists && rowCell.isHittable { rowCell.tap(); return }
            for c in containers where c.exists && c.isHittable { c.swipeUp() }
        }

        XCTAssertTrue(app.staticTexts[title].exists || rowCell.exists, "Row '\(title)' not found")
        let target = rowCell.exists ? rowCell : app.staticTexts[title]
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Returns likely scrollable containers on the current screen.
    private func scrollableContainers(in app: XCUIApplication) -> [XCUIElement] {
        return [app.tables.firstMatch,
                app.collectionViews.firstMatch,
                app.scrollViews.firstMatch]
            .filter { $0.exists }
    }

    /// Scrolls containers until element is hittable or max swipes reached.
    private func scrollToElement(_ element: XCUIElement, containers: [XCUIElement], maxSwipes: Int) {
        guard !containers.isEmpty else { return }
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            for c in containers where c.exists && c.isHittable { c.swipeUp() }
        }
    }

    /// Waits for a specific task to appear in the current list.
    @discardableResult
    private func waitForTask(named name: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if app.cells.containing(.staticText, identifier: name).firstMatch.exists { return true }
            if let container = ([app.tables.firstMatch, app.collectionViews.firstMatch, app.scrollViews.firstMatch]
                                    .first(where: { $0.exists && $0.isHittable })) {
                container.swipeDown()
                container.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < end
        return app.cells.containing(.staticText, identifier: name).firstMatch.exists
    }

    /// Waits for evidence that the task details screen is onscreen.
    private func waitForTaskDetails(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if app.staticTexts["Task Details"].exists { return true }
            if app.buttons["Edit"].exists { return true }
            if app.staticTexts["Assignees"].exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < end
        return app.staticTexts["Task Details"].exists || app.buttons["Edit"].exists || app.staticTexts["Assignees"].exists
    }

    /// Waits for a navigation bar title to appear (handles SwiftUI large/small titles).
    private func waitForNavTitle(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if app.navigationBars.staticTexts[title].exists { return true }
            if app.staticTexts[title].exists && app.staticTexts[title].isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < end
        return app.navigationBars.staticTexts[title].exists || app.staticTexts[title].exists
    }

    /// Taps the top-left back button if present.
    private func tapBack(_ app: XCUIApplication) {
        let navBack = app.navigationBars.buttons.firstMatch
        if navBack.waitForExistence(timeout: 3) { navBack.tap(); return }
        let back = app.buttons["Back"]
        if back.waitForExistence(timeout: 2) { back.tap() }
    }

    /// Taps a specific nav bar button by label (e.g., "Done").
    private func tapNavButton(_ label: String, app: XCUIApplication) {
        if app.navigationBars.buttons[label].waitForExistence(timeout: 3) {
            app.navigationBars.buttons[label].tap(); return
        }
        if app.buttons[label].waitForExistence(timeout: 2) {
            app.buttons[label].tap(); return
        }
        XCTFail("Nav button '\(label)' not found")
    }

    /// Taps an element when hittable; otherwise attempts a safe coordinate tap.
    private func tapWhenHittableOrCoordinate(_ element: XCUIElement,
                                             timeout: TimeInterval,
                                             failureMessage: String) {
        guard element.waitForHittable(timeout: timeout) else {
            if element.exists {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                XCTFail(failureMessage)
            }
            return
        }
        element.tap()
    }
}

// MARK: - XCUIElement helper

private extension XCUIElement {
    /// Waits until the element both exists and is hittable.
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return exists && isHittable
    }
}

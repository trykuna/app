import XCTest

final class KunaUITests: XCTestCase {

    private var isIPad: Bool = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    override func tearDownWithError() throws { }

    // MARK: - Test

    @MainActor
    func testGenerateScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("-UITestsNoAnimations")
        app.launchArguments += ["-AppleInterfaceStyle", "Light"]
        app.launch()

        // Detect if we're running on iPad based on device traits
        isIPad = detectIPad(app)

        // Handle first‑launch analytics prompt so the run doesn't stall
        dismissAnalyticsPrompt(app)

        var projectName = "Marketing Website"
        var detailTask  = "Fix 404s"

        // 01 — App launch
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        snapshot("01-AppLaunch")

        // Login if needed
        loginIfNeeded(app)

        // Ensure we’re on Projects
        ensureOnProjects(app)

        // Open project (fallbacks if the preferred one isn't present)
        let actualProject = openProjectAndReturnName(preferred: projectName, in: app)
        projectName = actualProject

        // Wait until the task list is visible (accept any task if specific one not found)
        XCTAssertTrue(waitForTask(named: detailTask, in: app, timeout: 10),
                      "Didn't enter \(projectName) task list")
        snapshot("02-TaskList")

        // Open the specific task (may fall back); on iPhone this now taps the chevron
        let actualTask = openTaskAndReturnName(preferred: detailTask, in: app)
        detailTask = actualTask

        // Ensure Task Details is shown
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 8), "Task details screen didn't appear")
        snapshot("04-TaskDetails")

        // --- Related Tasks screen ---
        openRow(titled: "Related Tasks", in: app)
        XCTAssertTrue(waitForNavTitle("Related Tasks", in: app, timeout: 6),
                      "Related Tasks screen didn’t appear")
        snapshot("05-RelatedTasks")

        // Close Related Tasks via Done
        tapNavOrAnyButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4), "Did not return to Task Details after Done")

        // --- Comments screen ---
        openRow(titled: "Comments", in: app)
        XCTAssertTrue(waitForNavTitle("Comments", in: app, timeout: 6),
                      "Comments screen didn't appear")
        snapshot("06-Comments")

        tapNavOrAnyButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4),
                      "Did not return to Task Details after leaving Comments")

        // --- Labels via sidebar ---
        openSidebar(app)
        tapSidebarItem("labels", app: app)

        // Verify Labels screen
        let labelsScreen = app.otherElements["screen.labels"].waitForExistence(timeout: 8) ||
                           app.staticTexts["Labels"].waitForExistence(timeout: 2)
        XCTAssertTrue(labelsScreen, "Labels screen didn't appear")
        snapshot("03-LabelsView")
        
//        // --- Favorites via sidebar ---
//        openSidebar(app)
//        tapSidebarItem("favorites", app: app)
//
//        // Verify Labels screen
//        let favoritesScreen = app.otherElements["screen.favorites"].waitForExistence(timeout: 8) ||
//                           app.staticTexts["Favorites"].waitForExistence(timeout: 2)
//        XCTAssertTrue(favoritesScreen, "Favorites screen didn't appear")
//        snapshot("04-FavoritesView")

        // --- Settings → Display Options ---
        openSidebar(app)
        tapSidebarItem("settings", app: app)

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8),
                      "Settings screen didn't appear")

        openSettingsRow(titled: "Display Options", in: app)

        XCTAssertTrue(waitForNavTitle("Display Options", in: app, timeout: 6),
                      "Display Options screen didn’t appear")
        snapshot("07-DisplayOptions")

        // AX dump on teardown for easier triage later
        addTeardownBlock {
            let dump = app.debugDescription
            let att = XCTAttachment(string: dump)
            att.lifetime = .keepAlways
            self.add(att)
        }
    }

    // A focused iPhone flow mirroring the iPad flow, kept in this main suite.
    @MainActor
    func testPhoneFlow() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("-UITestsNoAnimations")
        app.launch()

        // Skip on iPad; the primary test already covers iPad thoroughly
        let runningOnIPad = detectIPad(app)
        if runningOnIPad { throw XCTSkip("iPad flow covered by testGenerateScreenshots") }

        // First‑launch and auth
        dismissAnalyticsPrompt(app)
        loginIfNeeded(app)
        ensureOnProjects(app)

        // Project -> Task list
        _ = openProjectAndReturnName(preferred: "Marketing Website", in: app)
        XCTAssertTrue(waitForTask(named: "Fix 404s", in: app, timeout: 10))

        // Open a task, assert details (chevron‑first)
        _ = openTaskAndReturnName(preferred: "Fix 404s", in: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 8))

        // Related Tasks
        openRow(titled: "Related Tasks", in: app)
        XCTAssertTrue(waitForNavTitle("Related Tasks", in: app, timeout: 6))
        tapNavOrAnyButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4))

        // Comments
        openRow(titled: "Comments", in: app)
        XCTAssertTrue(waitForNavTitle("Comments", in: app, timeout: 6))
        tapNavOrAnyButton("Done", app: app)
        XCTAssertTrue(waitForTaskDetails(in: app, timeout: 4))

        // Back to Projects (label‑agnostic for iPhone)
        navigateBackToProjects(app)
        ensureOnProjects(app)

        // Sidebar -> Labels
        openSidebar(app)
        tapSidebarItem("labels", app: app)
        let labelsScreen = app.otherElements["screen.labels"].waitForExistence(timeout: 8) ||
                           app.staticTexts["Labels"].waitForExistence(timeout: 2)
        XCTAssertTrue(labelsScreen, "Labels screen didn't appear")

        // Sidebar -> Settings -> Display Options
        openSidebar(app)
        tapSidebarItem("settings", app: app)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        openSettingsRow(titled: "Display Options", in: app)
        XCTAssertTrue(waitForNavTitle("Display Options", in: app, timeout: 6))
    }

    // MARK: - Device Detection

    private func detectIPad(_ app: XCUIApplication) -> Bool {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        if device.lowercased().contains("ipad") { return true }
        return app.frame.width >= 768
    }

    // MARK: - First‑launch helpers

    private func dismissAnalyticsPrompt(_ app: XCUIApplication) {
        _ = app.wait(for: .runningForeground, timeout: 3)
        let allowButton = app.buttons["Allow Anonymous Analytics"]
        let denyButton  = app.buttons["No Thanks"]
        if denyButton.waitForHittable(timeout: 1.5) { denyButton.tap() }
        else if allowButton.waitForHittable(timeout: 1.0) { allowButton.tap() }
    }

    // MARK: - Sidebar / Login helpers

    /// Walks back via nav bar until the MenuButton is visible (or we're already on Projects).
    private func ensureMenuContext(_ app: XCUIApplication) {
        for _ in 0..<5 {
            if app.buttons["MenuButton"].exists { return }
            if app.otherElements["screen.projects"].exists { return }
            // Try tapping the first hittable nav button (iPhone-friendly)
            if let back = firstHittableNavButton(in: app) {
                back.tap()
            } else if app.navigationBars.buttons["Projects"].exists &&
                      app.navigationBars.buttons["Projects"].isHittable {
                app.navigationBars.buttons["Projects"].tap()
            } else {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(app.buttons["MenuButton"].exists || app.otherElements["screen.projects"].exists,
                      "MenuButton not visible; navigate back to a screen with the main menu or Projects.")
    }

    /// Opens the side menu by tapping MenuButton (no edge‑drag). Verifies via Sidebar container visibility.
    private func openSidebar(_ app: XCUIApplication) {
        ensureMenuContext(app)
        let menu = app.buttons["MenuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()

        // Main container has accessibilityIdentifier("Sidebar") and is hidden when closed.
        let sidebar = app.otherElements["Sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 3.0),
                      "Sidebar did not appear after tapping MenuButton.")
        // Small pause so the overlay and hit-testing settle
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    /// Taps a menu item by its Sidebar.* identifier. Assumes the drawer is already open.
    private func tapSidebarItem(_ itemKey: String, app: XCUIApplication) {
        let targetId = "Sidebar.\(itemKey.capitalized)"   // e.g. Sidebar.Settings
        let target = app.buttons.matching(identifier: targetId).firstMatch
        if target.waitForHittable(timeout: 1.0) { target.tap(); return }
        if target.exists {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); return
        }
        // Super‑tolerant fallback by label (rarely needed)
        let label = itemKey.capitalized
        let anyWithLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
        if anyWithLabel.exists {
            anyWithLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); return
        }
        XCTFail("Sidebar item '\(targetId)' not found.")
    }

    // MARK: - Screens & Auth

    private func ensureOnProjects(_ app: XCUIApplication) {
        let screenExists = app.otherElements["screen.projects"].waitForExistence(timeout: 8) ||
                           app.staticTexts["Projects"].waitForExistence(timeout: 2)
        XCTAssertTrue(screenExists, "Projects screen didn't appear")
    }

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
            usernameField.tap(); usernameField.typeText(username)
        }
        if passwordField.waitForExistence(timeout: 2) {
            passwordField.tap(); passwordField.typeText(password)
        }
        if loginButton.waitForExistence(timeout: 2) { loginButton.tap() }

        ensureOnProjects(app)
    }

    // MARK: - Navigation helpers (projects/tasks)

    private func openProject(named preferredName: String, in app: XCUIApplication) {
        if tryOpenProject(named: preferredName, in: app) { return }
        let availableProjects = discoverAvailableProjects(in: app)
        guard !availableProjects.isEmpty else {
            XCTFail("No projects found on the Projects screen"); return
        }
        for projectName in availableProjects {
            if tryOpenProject(named: projectName, in: app) { return }
        }
        XCTFail("Could not open any project. Preferred: '\(preferredName)', Available: \(availableProjects)")
    }

    private func tryOpenProject(named name: String, in app: XCUIApplication) -> Bool {
        let projectRows = app.buttons.matching(identifier: "project.row")
        for i in 0..<projectRows.count {
            let row = projectRows.element(boundBy: i)
            if row.exists && row.staticTexts[name].exists && row.isHittable { row.tap(); return true }
        }
        if app.cells.staticTexts[name].exists
            && app.cells.staticTexts[name].isHittable { app.cells.staticTexts[name].tap(); return true }
        if app.staticTexts[name].exists && app.staticTexts[name].isHittable { app.staticTexts[name].tap(); return true }

        let containers = scrollableContainers(in: app)
        for _ in 0..<12 {
            let target = app.staticTexts[name]
            if target.exists && target.isHittable { target.tap(); return true }
            let cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.exists && cell.isHittable { cell.tap(); return true }
            let projectRows = app.buttons.matching(identifier: "project.row")
            for i in 0..<projectRows.count {
                let row = projectRows.element(boundBy: i)
                if row.exists && row.staticTexts[name].exists && row.isHittable { row.tap(); return true }
            }
            for c in containers where c.exists && c.isHittable { c.swipeUp() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func discoverAvailableProjects(in app: XCUIApplication) -> [String] {
        var projectNames: Set<String> = []
        let containers = scrollableContainers(in: app)
        for scrollAttempt in 0..<8 {
            let projectRows = app.buttons.matching(identifier: "project.row")
            for i in 0..<projectRows.count {
                let row = projectRows.element(boundBy: i)
                if row.exists {
                    for text in row.staticTexts.allElementsBoundByIndex {
                        let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !label.isEmpty && label.count < 100 { projectNames.insert(label) }
                    }
                }
            }
            for text in app.staticTexts.allElementsBoundByIndex {
                let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty && !label.contains("Projects") && !label.contains("No projects") && label.count < 100 && text.exists {
                    projectNames.insert(label)
                }
            }
            for c in containers where c.exists && c.isHittable {
                (scrollAttempt % 2 == 0) ? c.swipeUp() : c.swipeDown()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return Array(projectNames).sorted()
    }

    private func openProjectAndReturnName(preferred: String, in app: XCUIApplication) -> String {
        if tryOpenProject(named: preferred, in: app) { return preferred }
        let availableProjects = discoverAvailableProjects(in: app)
        guard !availableProjects.isEmpty else { XCTFail("No projects found on the Projects screen"); return preferred }
        for projectName in availableProjects {
            if tryOpenProject(named: projectName, in: app) { return projectName }
        }
        XCTFail("Could not open any project. Preferred: '\(preferred)', Available: \(availableProjects)")
        return preferred
    }

    private func openTaskAndReturnName(preferred: String, in app: XCUIApplication) -> String {
        if isIPad { return selectTaskOnIPadAndReturnName(preferred: preferred, in: app) }
        if tryOpenTaskOnPhone(named: preferred, in: app) { return preferred }
        let availableTasks = discoverAvailableTasksOnPhone(in: app)
        guard !availableTasks.isEmpty else { XCTFail("No tasks found in the task list"); return preferred }
        for taskName in availableTasks {
            if tryOpenTaskOnPhone(named: taskName, in: app) { return taskName }
        }
        XCTFail("Could not open any task. Preferred: '\(preferred)', Available: \(availableTasks)")
        return preferred
    }

    private func selectTaskOnIPadAndReturnName(preferred: String, in app: XCUIApplication) -> String {
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] ''")).firstMatch.waitForExistence(timeout: 5)
        if trySelectTask(named: preferred, in: app) { return preferred }
        let availableTasks = discoverAvailableTasks(in: app)
        guard !availableTasks.isEmpty else { XCTFail("No tasks found in iPad split view"); return preferred }
        for taskName in availableTasks {
            if trySelectTask(named: taskName, in: app) { return taskName }
        }
        XCTFail("Could not select any task in iPad split view. Preferred: '\(preferred)', Available: \(availableTasks)")
        return preferred
    }

    private func openTask(named name: String, in app: XCUIApplication) {
        if isIPad { selectTaskOnIPad(named: name, in: app); return }
        _ = tryOpenTaskOnPhone(named: name, in: app)
    }

    // ---- iPhone: open task by tapping the trailing disclosure/chevron if present
    private func tryOpenTaskOnPhone(named name: String, in app: XCUIApplication) -> Bool {
        func attemptInCurrentViewport() -> Bool {
            // Find the row containing the title and identifier "task.row"
            let row = app.otherElements
                .matching(identifier: "task.row")
                .containing(.staticText, identifier: name)
                .firstMatch

            if row.exists {
                // 1) Prefer the chevron inside this row
                let chevronInRow = row.descendants(matching: .image)["task.row.disclosure"]
                if chevronInRow.exists && chevronInRow.isHittable {
                    chevronInRow.tap()
                    return true
                }
                // 2) Global chevron that overlaps this row’s frame (belt & braces)
                let globalChevron = app.images["task.row.disclosure"]
                if globalChevron.exists && globalChevron.isHittable &&
                    globalChevron.frame.intersects(row.frame) {
                    globalChevron.tap()
                    return true
                }
                // 3) Fallback: tap near the right edge of the row to avoid the left circle
                row.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
                return true
            }

            // Older fallback: cell that contains the title
            let cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.exists && cell.isHittable {
                let chevron = cell.descendants(matching: .image)["task.row.disclosure"]
                if chevron.exists && chevron.isHittable { chevron.tap(); return true }
                cell.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
                return true
            }

            return false
        }

        if attemptInCurrentViewport() { return true }

        // Scroll & retry alternating directions
        let containers = scrollableContainers(in: app)
        for attempt in 0..<12 {
            for c in containers where c.exists && c.isHittable {
                (attempt % 2 == 0) ? c.swipeUp() : c.swipeDown()
            }
            if attemptInCurrentViewport() { return true }
        }
        return false
    }

    private func discoverAvailableTasksOnPhone(in app: XCUIApplication) -> [String] {
        var taskNames: Set<String> = []
        let containers = scrollableContainers(in: app)
        for scrollAttempt in 0..<8 {
            let taskRows = app.buttons.matching(identifier: "task.row")
            for i in 0..<taskRows.count {
                let row = taskRows.element(boundBy: i)
                if row.exists {
                    for text in row.staticTexts.allElementsBoundByIndex {
                        let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !label.isEmpty && label.count < 100 { taskNames.insert(label) }
                    }
                }
            }
            for text in app.staticTexts.allElementsBoundByIndex {
                let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty && !label.contains("Tasks") && !label.contains("No tasks") &&
                   !label.contains("Loading") && label.count < 100 && text.exists {
                    taskNames.insert(label)
                }
            }
            for c in containers where c.exists && c.isHittable {
                (scrollAttempt % 2 == 0) ? c.swipeUp() : c.swipeDown()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return Array(taskNames).sorted()
    }

    private func openRow(titled title: String, in app: XCUIApplication) {
        if app.staticTexts[title].exists && app.staticTexts[title].isHittable { app.staticTexts[title].tap(); return }
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

    private func scrollableContainers(in app: XCUIApplication) -> [XCUIElement] {
        return [app.tables.firstMatch, app.collectionViews.firstMatch, app.scrollViews.firstMatch].filter { $0.exists }
    }

    private func scrollToElement(_ element: XCUIElement, containers: [XCUIElement], maxSwipes: Int) {
        guard !containers.isEmpty else { return }
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            for c in containers where c.exists && c.isHittable { c.swipeUp() }
        }
    }

    @discardableResult
    private func waitForTask(named name: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        var hasAnyTask = false
        repeat {
            let taskRows = app.buttons.matching(identifier: "task.row")
            for i in 0..<taskRows.count {
                let row = taskRows.element(boundBy: i)
                if row.exists {
                    hasAnyTask = true
                    if row.staticTexts[name].exists { return true }
                }
            }
            if app.cells.containing(.staticText, identifier: name).firstMatch.exists { return true }

            let anyTaskText = app.staticTexts.allElementsBoundByIndex.first { text in
                let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                return !label.isEmpty && !label.contains("Tasks") && !label.contains("Select a task") &&
                       !label.contains("Loading") && label.count < 100 && text.exists
            }
            if anyTaskText != nil { hasAnyTask = true }

            if let container = ([app.tables.firstMatch, app.collectionViews.firstMatch, app.scrollViews.firstMatch]
                                    .first(where: { $0.exists && $0.isHittable })) {
                container.swipeDown(); container.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < end

        let taskRows = app.buttons.matching(identifier: "task.row")
        for i in 0..<taskRows.count {
            let row = taskRows.element(boundBy: i)
            if row.exists && row.staticTexts[name].exists { return true }
        }
        if app.cells.containing(.staticText, identifier: name).firstMatch.exists { return true }
        if hasAnyTask { return true }
        return false
    }

    private func waitForTaskDetails(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if app.staticTexts["Task Details"].exists { return true }
            if app.buttons["Edit"].exists { return true }
            if app.staticTexts["Assignees"].exists { return true }
            if app.staticTexts["Comments"].exists || app.buttons["Comments"].exists { return true }
            if app.staticTexts["Related Tasks"].exists || app.buttons["Related Tasks"].exists { return true }
            if isIPad {
                if app.staticTexts["TASK INFO"].exists { return true }
                if app.staticTexts["SCHEDULING"].exists { return true }
                if app.staticTexts["ORGANIZATION"].exists { return true }
                let indicators = ["Title", "Description", "Priority", "Due Date", "Start Date", "End Date", "Project", "Labels"]
                for ind in indicators { if app.staticTexts[ind].exists { return true } }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < end
        return app.staticTexts["Task Details"].exists || app.buttons["Edit"].exists || app.staticTexts["Assignees"].exists || app.staticTexts["Comments"].exists || app.staticTexts["Related Tasks"].exists
    }

    private func waitForNavTitle(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if app.navigationBars.staticTexts[title].exists { return true }
            if app.staticTexts[title].exists && app.staticTexts[title].isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < end
        return app.navigationBars.staticTexts[title].exists || app.staticTexts[title].exists
    }

    // iPhone-friendly “go back to Projects” without relying on the label text.
    private func navigateBackToProjects(_ app: XCUIApplication) {
        for _ in 0..<6 {
            if app.otherElements["screen.projects"].exists { return }
            if let back = firstHittableNavButton(in: app) {
                back.tap()
            } else if app.buttons["Back"].exists && app.buttons["Back"].isHittable {
                app.buttons["Back"].tap()
            } else if app.navigationBars.buttons.element(boundBy: 0).exists &&
                      app.navigationBars.buttons.element(boundBy: 0).isHittable {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(app.otherElements["screen.projects"].exists || app.staticTexts["Projects"].exists,
                      "Failed to navigate back to Projects.")
    }

    // MARK: - iPad helpers

    private func selectTaskOnIPad(named preferredName: String, in app: XCUIApplication) {
        _ = app.wait(for: .runningForeground, timeout: 3)
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 8)
        if trySelectTask(named: preferredName, in: app) { return }

        let availableTasks = discoverAvailableTasks(in: app)
        guard !availableTasks.isEmpty else { XCTFail("No tasks found in iPad split view"); return }
        for taskName in availableTasks {
            if trySelectTask(named: taskName, in: app) { return }
        }

        let allTexts = app.staticTexts.allElementsBoundByIndex
        for text in allTexts where text.exists && text.isHittable && !text.label.isEmpty &&
                                  !text.label.contains("Tasks") && !text.label.contains("Select a task") {
            text.tap()
            if waitForTaskDetails(in: app, timeout: 2) { return }
        }
        XCTFail("Could not select any task in iPad split view.")
    }

    private func trySelectTask(named name: String, in app: XCUIApplication) -> Bool {
        let taskText = app.staticTexts[name]
        if taskText.exists && taskText.isHittable {
            taskText.tap()
            return waitForTaskDetails(in: app, timeout: 3)
        }
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if cell.exists && cell.isHittable {
            cell.tap()
            return waitForTaskDetails(in: app, timeout: 3)
        }
        let list = app.tables.firstMatch
        if list.exists {
            for attempt in 0..<8 {
                let taskText = app.staticTexts[name]
                if taskText.exists && taskText.isHittable { taskText.tap(); return waitForTaskDetails(in: app, timeout: 3) }
                let cell = app.cells.containing(.staticText, identifier: name).firstMatch
                if cell.exists && cell.isHittable { cell.tap(); return waitForTaskDetails(in: app, timeout: 3) }
                (attempt % 2 == 0) ? list.swipeUp() : list.swipeDown()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        return false
    }

    private func discoverAvailableTasks(in app: XCUIApplication) -> [String] {
        var taskNames: Set<String> = []
        let list = app.tables.firstMatch
        if list.exists {
            for attempt in 0..<6 {
                for text in app.staticTexts.allElementsBoundByIndex {
                    let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !label.isEmpty && !label.contains("Tasks") && !label.contains("Select a task") &&
                       !label.contains("Loading") && label.count < 100 && text.exists {
                        taskNames.insert(label)
                    }
                }
                (attempt % 2 == 0) ? list.swipeUp() : list.swipeDown()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        return Array(taskNames).sorted()
    }
}

// MARK: - XCUIElement helpers

private extension XCUIElement {
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return exists && isHittable
    }
}

// MARK: - Navbar/helpers (shared)

private func firstHittableNavButton(in app: XCUIApplication) -> XCUIElement? {
    let navButtons = app.navigationBars.buttons
    for i in 0..<navButtons.count {
        let b = navButtons.element(boundBy: i)
        if b.exists && b.isHittable { return b }
    }
    return nil
}

/// Opens a row inside the Settings sheet (case-insensitive).
private func openSettingsRow(titled wantedTitle: String, in app: XCUIApplication) {
    XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8), "Settings screen didn't appear")
    let container = app.sheets.firstMatch.exists
        ? app.sheets.firstMatch
        : (app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app)

    let ids = ["settings.displayOptions", "settings.display", "settings.appearance", "Display Options", "Display options", "Display"]
    for id in ids {
        let btn = container.buttons.matching(identifier: id).firstMatch
        if btn.exists && btn.isHittable { btn.tap(); return }
        let cell = container.cells.matching(identifier: id).firstMatch
        if cell.exists && cell.isHittable { cell.tap(); return }
    }

    let pred = NSPredicate(format: "label CONTAINS[c] %@", wantedTitle)
    let queries: [XCUIElementQuery] = [
        container.buttons.containing(pred),
        container.cells.containing(pred),
        container.staticTexts.containing(pred)
    ]

    for q in queries {
        let e = q.firstMatch
        if e.exists && e.isHittable { e.tap(); return }
    }

    let scroll = container.scrollViews.firstMatch.exists ? container.scrollViews.firstMatch
               : (container.tables.firstMatch.exists ? container.tables.firstMatch : container)
    if scroll.exists && scroll.isHittable {
        for _ in 0..<8 {
            for q in queries {
                let e = q.firstMatch
                if e.exists && e.isHittable { e.tap(); return }
            }
            scroll.swipeUp()
        }
        for _ in 0..<3 { scroll.swipeDown() }
        for q in queries {
            let e = q.firstMatch
            if e.exists { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); return }
        }
    }

    XCTFail("Row '\(wantedTitle)' not found in Settings.")
}

// MARK: - Nav button helpers

/// Smarter nav-button tap that falls back to the first hittable navbar button.
private func tapNavButton(_ label: String, app: XCUIApplication) {
    if app.navigationBars.buttons[label].waitForExistence(timeout: 2.0) {
        app.navigationBars.buttons[label].tap(); return
    }
    if app.buttons[label].waitForExistence(timeout: 1.0) {
        app.buttons[label].tap(); return
    }
    if let back = firstHittableNavButton(in: app) { back.tap(); return }
    XCTFail("Nav button '\(label)' not found and no generic back button available.")
}

/// Like tapNavButton but will also attempt unlabeled toolbar/sheet buttons,
/// then fall back to a generic nav/back button if needed.
private func tapNavOrAnyButton(_ label: String, app: XCUIApplication) {
    // 1) Try navigation bar button with this title
    if app.navigationBars.buttons[label].waitForExistence(timeout: 1.0) {
        app.navigationBars.buttons[label].tap(); return
    }
    // 2) Try a regular button by identifier or title
    let byId = app.buttons.matching(identifier: label).firstMatch
    if byId.exists && byId.isHittable { byId.tap(); return }
    let byTitle = app.buttons[label]
    if byTitle.exists && byTitle.isHittable { byTitle.tap(); return }

    // 3) Common containers (sheets / toolbars)
    let sheetBtn = app.sheets.buttons[label]
    if sheetBtn.exists && sheetBtn.isHittable { sheetBtn.tap(); return }
    let toolbarBtn = app.toolbars.buttons[label]
    if toolbarBtn.exists && toolbarBtn.isHittable { toolbarBtn.tap(); return }

    // 4) Fallback to the first hittable nav button (often Back)
    if let back = firstHittableNavButton(in: app) { back.tap(); return }

    // 5) Absolute last resort: first hittable button on screen
    let any = app.buttons.firstMatch
    if any.exists && any.isHittable { any.tap(); return }

    XCTFail("Could not find a tappable button for '\(label)'")
}

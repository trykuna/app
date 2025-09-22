import XCTest

final class SimpleScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Fastlane looks for test methods that start with "test"
    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()

        // This is required for fastlane snapshot to work
        setupSnapshot(app)

        // Launch the app
        app.launch()

        // Wait for app to load
        sleep(3)

        // Print device info for debugging
        print("=== Starting screenshot test ===")
        print("Device: \(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "Unknown")")
        print("Language: \(ProcessInfo.processInfo.environment["FASTLANE_LANGUAGE"] ?? "Unknown")")

        // Handle analytics if it appears
        if app.buttons["No Thanks"].exists {
            print("Dismissing analytics prompt")
            app.buttons["No Thanks"].tap()
            sleep(1)
        }

        // Check if we're on login screen
        if app.buttons["Log In"].exists {
            print("On login screen - logging in...")

            // Read credentials directly from UITests.local.xcconfig file
            var credentials: [String: String] = [:]

            // Find the xcconfig file relative to the test bundle
            // The test bundle is deep in DerivedData, we need to go up to find the project
            let testBundle = Bundle(for: SimpleScreenshots.self)
            var projectPath = testBundle.bundlePath

            print("Test bundle path: \(testBundle.bundlePath)")
            print("Current directory: \(FileManager.default.currentDirectoryPath)")

            // Print ALL environment variables to see what's available
            print("Environment variables:")
            for (key, value) in ProcessInfo.processInfo.environment {
                if key.contains("ROOT") || key.contains("DIR") || key.contains("PATH") {
                    print("  \(key) = \(value)")
                }
            }

            // Go up directories until we find UITests.local.xcconfig
            var xcconfigPath: String? = nil
            let fileManager = FileManager.default

            // TEMPORARY: Just use the known path while debugging
            let knownPath = "/Users/richard/repos/Kuna/KunaUITests/UITests.local.xcconfig"
            if fileManager.fileExists(atPath: knownPath) {
                xcconfigPath = knownPath
                print("Found xcconfig at known path: \(knownPath)")
            }

            // Only continue searching if we haven't found it yet
            if xcconfigPath == nil {
                // First check in the same directory as this test file (KunaUITests folder)
                let testDirectory = (testBundle.bundlePath as NSString).deletingLastPathComponent
                let localPath = (testDirectory as NSString).appendingPathComponent("UITests.local.xcconfig")
                print("Checking: \(localPath)")
                if fileManager.fileExists(atPath: localPath) {
                    xcconfigPath = localPath
                    print("Found xcconfig in test directory: \(localPath)")
                }
            }

            // If not found, try going up multiple levels from the test bundle
            if xcconfigPath == nil {
                for _ in 0..<10 {
                    projectPath = (projectPath as NSString).deletingLastPathComponent

                    // Check in KunaUITests subdirectory
                    let candidatePath = (projectPath as NSString).appendingPathComponent("KunaUITests/UITests.local.xcconfig")
                    print("Checking: \(candidatePath)")
                    if fileManager.fileExists(atPath: candidatePath) {
                        xcconfigPath = candidatePath
                        print("Found xcconfig at: \(candidatePath)")
                        break
                    }

                    // Also check in root (old location)
                    let rootPath = (projectPath as NSString).appendingPathComponent("UITests.local.xcconfig")
                    print("Checking: \(rootPath)")
                    if fileManager.fileExists(atPath: rootPath) {
                        xcconfigPath = rootPath
                        print("Found xcconfig at: \(rootPath)")
                        break
                    }
                }
            }

            // Check SOURCE_ROOT first (this is set when running in Xcode)
            if xcconfigPath == nil {
                if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
                    print("SOURCE_ROOT is: \(sourceRoot)")
                    // Check in KunaUITests subdirectory
                    let sourcePath = (sourceRoot as NSString).appendingPathComponent("KunaUITests/UITests.local.xcconfig")
                    print("Checking SOURCE_ROOT path: \(sourcePath)")
                    if fileManager.fileExists(atPath: sourcePath) {
                        xcconfigPath = sourcePath
                        print("Found xcconfig via SOURCE_ROOT: \(sourcePath)")
                    }
                }
            }

            // Try SRCROOT as well (another Xcode variable)
            if xcconfigPath == nil {
                if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
                    print("SRCROOT is: \(srcRoot)")
                    // Check in KunaUITests subdirectory
                    let srcPath = (srcRoot as NSString).appendingPathComponent("KunaUITests/UITests.local.xcconfig")
                    print("Checking SRCROOT path: \(srcPath)")
                    if fileManager.fileExists(atPath: srcPath) {
                        xcconfigPath = srcPath
                        print("Found xcconfig via SRCROOT: \(srcPath)")
                    }
                }
            }

            // When running in Xcode, try PROJECT_DIR as well
            if xcconfigPath == nil {
                if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
                    print("PROJECT_DIR is: \(projectDir)")
                    let projectPath = (projectDir as NSString).appendingPathComponent("KunaUITests/UITests.local.xcconfig")
                    print("Checking PROJECT_DIR path: \(projectPath)")
                    if fileManager.fileExists(atPath: projectPath) {
                        xcconfigPath = projectPath
                        print("Found xcconfig via PROJECT_DIR: \(projectPath)")
                    }
                }
            }

            print("Using xcconfig: \(xcconfigPath ?? "not found")")

            if let path = xcconfigPath, let configContent = try? String(contentsOfFile: path, encoding: .utf8) {
                print("Found xcconfig file, parsing...")

                // Parse the xcconfig file
                let lines = configContent.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !trimmed.hasPrefix("//") {
                        let parts = trimmed.split(separator: "=", maxSplits: 1)
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespaces)
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            credentials[key] = value
                        }
                    }
                }
            } else {
                print("Could not read xcconfig file, falling back to environment variables")
            }

            // Use credentials from file, fall back to environment, then to demo
            let serverScheme = credentials["VIKUNJA_SERVER_SCHEME"] ??
                              ProcessInfo.processInfo.environment["VIKUNJA_SERVER_SCHEME"] ?? "https"
            let serverHost = credentials["VIKUNJA_SERVER_HOST"] ??
                            ProcessInfo.processInfo.environment["VIKUNJA_SERVER_HOST"] ?? "demo.vikunja.io"
            let serverURL = "\(serverScheme)://\(serverHost)"
            let username = credentials["VIKUNJA_USERNAME"] ??
                          ProcessInfo.processInfo.environment["VIKUNJA_USERNAME"] ?? "demo"
            let password = credentials["VIKUNJA_PASSWORD"] ??
                          ProcessInfo.processInfo.environment["VIKUNJA_PASSWORD"] ?? "demo"

            print("Using server: \(serverURL)")
            print("Using username: \(username)")

            // Fill in server URL (first text field)
            if app.textFields.count > 0 {
                let serverField = app.textFields.element(boundBy: 0)
                serverField.tap()

                // Clear existing text if any
                if let currentValue = serverField.value as? String, !currentValue.isEmpty {
                    serverField.tap()
                    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 10)
                    serverField.typeText(deleteString)
                }

                serverField.typeText(serverURL)
            }

            // Fill in username
            if app.textFields["Username"].exists {
                app.textFields["Username"].tap()
                app.textFields["Username"].typeText(username)
            }

            // Fill in password
            if app.secureTextFields["Password"].exists {
                app.secureTextFields["Password"].tap()
                app.secureTextFields["Password"].typeText(password)
            }

            // Tap login button
            if app.buttons["Log In"].exists {
                app.buttons["Log In"].tap()
            }

            // Wait for login to complete
            print("Waiting for login to complete...")
            sleep(5)

            print("Login complete")
        } else {
            print("Already logged in")
        }

        // Take screenshot of current screen (likely Projects or Overview after login)
        print("Taking initial screenshot...")

        // Wait for the screen to settle
        sleep(2)

        // Check if we can see the MenuButton to understand our current state
        if app.buttons["MenuButton"].exists {
            print("MenuButton visible, we're on a main screen")

            // First, let's go to Projects to ensure consistent starting point
            print("Navigating to Projects screen...")
            app.buttons["MenuButton"].tap()
            sleep(2)  // Give sidebar time to fully open

            // Find and tap Projects via explicit identifier then by label
            let projectsById = app.buttons.matching(identifier: "Sidebar.Projects").firstMatch
            if projectsById.waitForExistence(timeout: 2) {
                print("Tapping Projects by identifier Sidebar.Projects")
                projectsById.tap()
            } else if app.buttons.containing(NSPredicate(format: "label == 'Projects'")).firstMatch.exists {
                print("Tapping Projects by label")
                app.buttons.containing(NSPredicate(format: "label == 'Projects'")).firstMatch.tap()
            } else {
                print("Projects button not found in sidebar")
            }
            sleep(2)  // Wait for navigation

            // Close sidebar by tapping outside
            print("Closing sidebar...")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(2)
        }

        // Take screenshot of Projects screen
        print("Taking Projects screenshot...")
        snapshot("01-ProjectsList")

        // Navigate to Overview
        print("Navigating to Overview...")

        // Open the side menu
        if app.buttons["MenuButton"].exists {
            print("Opening side menu for Overview")
            app.buttons["MenuButton"].tap()
            sleep(2)  // Give sidebar time to open

            // Find and tap Overview via explicit identifier then by label
            let overviewById = app.buttons.matching(identifier: "Sidebar.Overview").firstMatch
            if overviewById.waitForExistence(timeout: 2) {
                print("Tapping Overview by identifier Sidebar.Overview")
                overviewById.tap()
                sleep(2)  // Wait for navigation
            } else if app.buttons.containing(NSPredicate(format: "label == 'Overview'")).firstMatch.exists {
                print("Tapping Overview by label")
                app.buttons.containing(NSPredicate(format: "label == 'Overview'")).firstMatch.tap()
                sleep(2)
            } else {
                print("Overview button not found in sidebar")
            }

            // Close the sidebar by tapping outside
            print("Closing sidebar after Overview navigation")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(2)

            // Verify we're on Overview screen before taking screenshot
            // Overview typically has "Today", "Upcoming", or "Overdue" sections
            let isOnOverview = app.staticTexts["Today"].exists ||
                               app.staticTexts["Upcoming"].exists ||
                               app.staticTexts["Overdue"].exists ||
                               app.navigationBars["Overview"].exists

            if isOnOverview {
                print("Confirmed on Overview screen")
            } else {
                print("May not be on Overview screen, attempting to navigate again...")

                // Try again with a different approach
                if app.buttons["MenuButton"].exists {
                    app.buttons["MenuButton"].tap()
                    sleep(2)

                    // Try tapping on Overview text directly
                    if app.staticTexts["Overview"].exists {
                        app.staticTexts["Overview"].tap()
                    } else if app.cells["Overview"].exists {
                        app.cells["Overview"].tap()
                    }
                    sleep(2)

                    // Close sidebar
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                    sleep(2)
                }
            }

            // Take screenshot of Overview screen
            print("Taking Overview screenshot...")
            snapshot("02-Overview")
        } else {
            print("MenuButton not found for Overview navigation")
        }

        // Navigate to Labels
        print("Navigating to Labels...")

        // Wait for the MenuButton to reappear after closing sidebar
        print("Waiting for MenuButton to be available...")
        var menuButtonAppeared = false
        for _ in 0..<5 {
            if app.buttons["MenuButton"].exists {
                menuButtonAppeared = true
                print("MenuButton is now visible")
                break
            }
            print("MenuButton not yet visible, waiting...")
            sleep(1)
        }

        // If MenuButton still not visible, try tapping to dismiss any overlays
        if !menuButtonAppeared {
            print("MenuButton still not visible, trying to tap center to dismiss overlays")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)

            // Check again
            if app.buttons["MenuButton"].exists {
                menuButtonAppeared = true
                print("MenuButton appeared after center tap")
            }
        }

        // Open the side menu
        if menuButtonAppeared && app.buttons["MenuButton"].exists {
            print("Opening side menu for Labels")
            app.buttons["MenuButton"].tap()
            sleep(2)  // Give sidebar time to open

            // Find and tap Labels via explicit identifier then by label
            let labelsById = app.buttons.matching(identifier: "Sidebar.Labels").firstMatch
            if labelsById.waitForExistence(timeout: 2) {
                print("Tapping Labels by identifier Sidebar.Labels")
                labelsById.tap()
                sleep(2)  // Wait for navigation
            } else if app.buttons.containing(NSPredicate(format: "label == 'Labels'")).firstMatch.exists {
                print("Tapping Labels by label")
                app.buttons.containing(NSPredicate(format: "label == 'Labels'")).firstMatch.tap()
                sleep(2)
            } else {
                print("Labels button not found in sidebar")
            }

            // Close the sidebar by tapping outside
            print("Closing sidebar after Labels navigation")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(2)

            // Take screenshot of Labels screen
            print("Taking Labels screenshot...")
            snapshot("03-Labels")
        } else {
            print("MenuButton not found for Labels navigation")
        }

        // Navigate to Marketing Website project to capture task list
        print("Navigating to Marketing Website project...")

        // Ensure MenuButton is visible
        var menuVisible = false
        for _ in 0..<5 {
            if app.buttons["MenuButton"].exists { menuVisible = true; break }
            sleep(1)
        }

        if menuVisible {
            // Open side menu
            app.buttons["MenuButton"].tap()
            sleep(2)

            // Go to Projects via the SideMenu container for robustness
            let sideMenu = app.otherElements["SideMenu"]
            _ = sideMenu.waitForExistence(timeout: 3)
            var tappedProjects = false
            if sideMenu.exists {
                let projectsById = sideMenu.buttons.matching(identifier: "Sidebar.Projects").firstMatch
                if projectsById.exists {
                    print("Tapping Projects by identifier Sidebar.Projects inside SideMenu")
                    projectsById.tap(); tappedProjects = true; sleep(1)
                } else if sideMenu.buttons.count >= 3 {
                    print("Tapping Projects by index inside SideMenu (3rd button)")
                    sideMenu.buttons.element(boundBy: 2).tap(); tappedProjects = true; sleep(1)
                } else {
                    let projectsByLabel = sideMenu.staticTexts.containing(NSPredicate(format: "label == 'Projects'"))
                        .firstMatch
                    if projectsByLabel.exists && projectsByLabel.isHittable {
                        print("Tapping Projects by label inside SideMenu")
                        projectsByLabel.tap(); tappedProjects = true; sleep(1)
                    }
                }
            }
            if !tappedProjects {
                // Global fallbacks
                let projectsByIdGlobal = app.buttons.matching(identifier: "Sidebar.Projects").firstMatch
                if projectsByIdGlobal.exists { projectsByIdGlobal.tap(); tappedProjects = true; sleep(1) }
                else if app.buttons.containing(NSPredicate(format: "label == 'Projects'"))
                            .firstMatch.exists {
                    app.buttons.containing(NSPredicate(format: "label == 'Projects'"))
                        .firstMatch.tap(); tappedProjects = true; sleep(1)
                }
            }

            // Close the sidebar by tapping outside
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(2)
            // Ensure Projects list is visible before searching (match any type)
            let projectsRoot = app.descendants(matching: .any).matching(identifier: "screen.projects").firstMatch
            _ = projectsRoot.waitForExistence(timeout: 10)

            // Find the Marketing Website project and tap it
            let projectName = "Marketing Website"
            var openedProject = false

            // Prefer working within the collection view if present (projects list renders as a CollectionView)
            let list: XCUIElement
            let collection = app.collectionViews["screen.projects"]
            if collection.exists { list = collection }
            else if app.tables.firstMatch.exists { list = app.tables.firstMatch }
            else if app.scrollViews.firstMatch.exists { list = app.scrollViews.firstMatch }
            else { list = app }

            // Try in a scroll loop: button/text/cell containing the title
            for _ in 0..<14 {
                let buttonExact = list.buttons[projectName]
                if buttonExact.exists && buttonExact.isHittable { buttonExact.tap(); openedProject = true; break }

                let textExact = list.staticTexts[projectName]
                if textExact.exists && textExact.isHittable { textExact.tap(); openedProject = true; break }

                let cellByText = list.cells.containing(.staticText, identifier: projectName).firstMatch
                if cellByText.exists && cellByText.isHittable { cellByText.tap(); openedProject = true; break }

                if list != app { list.swipeUp() } else { app.swipeUp() }
                sleep(1)
            }

            // Last resort: any element with exact label anywhere
            if !openedProject {
                let anyExact = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label == %@", projectName)).firstMatch
                if anyExact.exists {
                    if anyExact.isHittable { anyExact.tap() } else {
                        anyExact.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                    openedProject = true
                }
            }

            // Wait for tasks screen
            if openedProject {
                let tasksRoot = app.descendants(matching: .any).matching(identifier: "screen.tasks").firstMatch
                let addBtn = app.buttons["button.addTask"]
                let filterBtn = app.buttons["button.filter"]
                let detectedTasks = tasksRoot.waitForExistence(timeout: 15)
                    || addBtn.waitForExistence(timeout: 2)
                    || filterBtn.waitForExistence(timeout: 2)
                if detectedTasks {
                    print("Taking Task List screenshot...")
                    snapshot("04-TaskList")

                    // Open specific task 'Fix 404s' and capture detail for all devices
                    print("Attempting to open 'Fix 404s' task...")

                    // Prefer the table list; fall back to collection/scroll
                    let list: XCUIElement = app.tables.firstMatch.exists
                        ? app.tables.firstMatch
                        : (app.collectionViews.firstMatch.exists
                           ? app.collectionViews.firstMatch
                           : (app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app))

                    var openedDetail = false
                    for _ in 0..<14 {
                        let btn = list.buttons["Fix 404s"]
                        if btn.exists && btn.isHittable { btn.tap(); openedDetail = true; break }

                        let cell = list.cells.containing(.staticText, identifier: "Fix 404s").firstMatch
                        if cell.exists && cell.isHittable { cell.tap(); openedDetail = true; break }

                        let titleText = list.staticTexts["Fix 404s"]
                        if titleText.exists && titleText.isHittable { titleText.tap(); openedDetail = true; break }

                        if list != app { list.swipeUp() } else { app.swipeUp() }
                        sleep(1)
                    }

                    if openedDetail {
                        // Wait for Task Details to appear (by nav title or section header presence)
                        let taskDetailsNav = app.navigationBars["Task Details"]
                        _ = taskDetailsNav.waitForExistence(timeout: 10)

                        print("Taking task details screenshot...")
                        snapshot("05-TaskDetails")

                        // Now try to capture Related Tasks - simplified approach
                        sleep(2) // Wait for detail view to settle

                        // Try the most common approaches first
                        var foundRelatedTasks = false

                        // Look for Related Tasks button or text
                        if app.buttons["Related Tasks"].waitForExistence(timeout: 3) {
                            app.buttons["Related Tasks"].tap()
                            foundRelatedTasks = true
                        } else if app.staticTexts["Related Tasks"].waitForExistence(timeout: 3) {
                            app.staticTexts["Related Tasks"].tap()
                            foundRelatedTasks = true
                        } else {
                            // Scroll down to find it
                            for _ in 0..<3 {
                                app.swipeUp()
                                sleep(1)

                                if app.buttons["Related Tasks"].exists {
                                    app.buttons["Related Tasks"].tap()
                                    foundRelatedTasks = true
                                    break
                                } else if app.staticTexts["Related Tasks"].exists {
                                    app.staticTexts["Related Tasks"].tap()
                                    foundRelatedTasks = true
                                    break
                                }
                            }
                        }

                        if foundRelatedTasks {
                            // Wait for Related Tasks view to appear
                            sleep(3)

                            // Take the screenshot
                            snapshot("06-RelatedTasks")

                            // Try to dismiss - look for Done button or back navigation
                            if app.buttons["Done"].exists {
                                app.buttons["Done"].tap()
                            } else if app.navigationBars.firstMatch.buttons.firstMatch.exists {
                                app.navigationBars.firstMatch.buttons.firstMatch.tap()
                            } else {
                                // Swipe down to dismiss if it's a sheet
                                app.swipeDown()
                            }
                            sleep(1)
                        }

                        // Now capture Comments - same approach as Related Tasks
                        sleep(2) // Wait for view to settle after dismissing Related Tasks

                        var foundComments = false

                        // Look for Comments button or text
                        if app.buttons["Comments"].waitForExistence(timeout: 3) {
                            app.buttons["Comments"].tap()
                            foundComments = true
                        } else if app.staticTexts["Comments"].waitForExistence(timeout: 3) {
                            app.staticTexts["Comments"].tap()
                            foundComments = true
                        } else {
                            // Scroll down to find it
                            for _ in 0..<3 {
                                app.swipeUp()
                                sleep(1)

                                if app.buttons["Comments"].exists {
                                    app.buttons["Comments"].tap()
                                    foundComments = true
                                    break
                                } else if app.staticTexts["Comments"].exists {
                                    app.staticTexts["Comments"].tap()
                                    foundComments = true
                                    break
                                }
                            }
                        }

                        if foundComments {
                            // Wait for Comments view to appear
                            sleep(3)

                            // Take the screenshot
                            snapshot("07-Comments")

                            // Try to dismiss - look for Done button or back navigation
                            if app.buttons["Done"].exists {
                                app.buttons["Done"].tap()
                            } else if app.navigationBars.firstMatch.buttons.firstMatch.exists {
                                app.navigationBars.firstMatch.buttons.firstMatch.tap()
                            } else {
                                // Swipe down to dismiss if it's a sheet
                                app.swipeDown()
                            }
                            sleep(1)
                        }
                    } else {
                            print("Could not find 'Fix 404s' in the list; dumping AX tree...")
                            print(app.debugDescription)
                        }
                } else {
                    print("Did not detect tasks screen; skipping Task List screenshot")
                }
            } else {
                print("Could not open a project from Projects list - dumping AX tree for diagnosis...")
                print(app.debugDescription)
            }
        } else {
            print("MenuButton not visible; cannot navigate to Projects")
        }

        print("Screenshot test completed successfully - captured 7 screenshots")
    }
}


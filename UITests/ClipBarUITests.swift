import XCTest

@MainActor
final class ClipBarUITests: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-didOnboard", "YES", "-pasteboard.lastSeenChangeCount", "-1"]
    }

    private func allowPasteIfAsked(timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for host in [springboard, app] {
                let allow = host.buttons["Allow Paste"]
                if allow.exists { allow.tap(); return }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    private func setPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    func testCapturePinSearchAndMenu() throws {
        setPasteboard("https://developer.apple.com/documentation/swiftui")
        app.launch()
        allowPasteIfAsked()

        // Link captured and shown with its host as title.
        XCTAssertTrue(app.staticTexts["developer.apple.com"].waitForExistence(timeout: 5))
        takeScreenshot("all-after-link")

        // Capture a plain text and a path via the refresh button (simulates reopening).
        setPasteboard("sudo xcodebuild -license accept")
        app.buttons["Capture clipboard"].tap()
        allowPasteIfAsked()
        XCTAssertTrue(app.staticTexts["sudo xcodebuild -license accept"].waitForExistence(timeout: 5))

        setPasteboard("/Applications/Xcode.app")
        app.buttons["Capture clipboard"].tap()
        allowPasteIfAsked()
        XCTAssertTrue(app.staticTexts["Xcode.app"].waitForExistence(timeout: 5))
        takeScreenshot("all-three-items")

        // Tap copies: the toast appears.
        app.staticTexts["developer.apple.com"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Copied'")).firstMatch.waitForExistence(timeout: 3))

        // Pin via leading swipe.
        let cmdRow = app.staticTexts["sudo xcodebuild -license accept"]
        cmdRow.swipeRight()
        let pin = app.buttons["Pin"]
        if pin.waitForExistence(timeout: 2) { pin.tap() }

        // Side menu → Links section.
        app.buttons["Menu"].tap()
        XCTAssertTrue(app.buttons["menu.links"].waitForExistence(timeout: 3))
        takeScreenshot("side-menu")
        app.buttons["menu.links"].tap()
        XCTAssertTrue(app.navigationBars["Links"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["developer.apple.com"].exists)
        XCTAssertFalse(app.staticTexts["Xcode.app"].exists)

        // Pinned section contains the pinned command.
        app.buttons["Menu"].tap()
        app.buttons["menu.pinned"].tap()
        XCTAssertTrue(app.navigationBars["Pinned"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["sudo xcodebuild -license accept"].waitForExistence(timeout: 3))
        takeScreenshot("pinned")

        // Paths section.
        app.buttons["Menu"].tap()
        app.buttons["menu.paths"].tap()
        XCTAssertTrue(app.staticTexts["Xcode.app"].waitForExistence(timeout: 3))

        // Settings opens.
        app.buttons["Menu"].tap()
        app.buttons["menu.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        takeScreenshot("settings")
        app.buttons["Done"].tap()

        // Back to All, then search.
        app.buttons["Menu"].tap()
        app.buttons["menu.all"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("xcode")
        XCTAssertTrue(app.staticTexts["Xcode.app"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["developer.apple.com"].exists)
        takeScreenshot("search-xcode")
    }

    func testImageCaptureShowsInImagesSection() throws {
        let size = CGSize(width: 64, height: 40)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        UIPasteboard.general.image = image
        app.launch()
        allowPasteIfAsked()
        XCTAssertTrue(app.staticTexts["Image 64×40"].waitForExistence(timeout: 5) ||
                      app.staticTexts["Image 192×120"].waitForExistence(timeout: 1) ||
                      app.staticTexts["Image 128×80"].waitForExistence(timeout: 1))
        app.buttons["Menu"].tap()
        app.buttons["menu.images"].tap()
        XCTAssertTrue(app.navigationBars["Images"].waitForExistence(timeout: 3))
        takeScreenshot("images-grid")
    }

    private func takeScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

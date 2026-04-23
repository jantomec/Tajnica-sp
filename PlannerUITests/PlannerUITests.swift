import XCTest

final class PlannerUITests: XCTestCase {
    #if os(iOS)
    private enum SiriPhrase {
        static let capture = [
            "Open Capture in Tajnica s.p.",
            "Open Capture in Tajnica",
            "Show Capture in Tajnica",
            "Open Capture"
        ]

        static let review = [
            "Open Review in Tajnica s.p.",
            "Open Review in Tajnica",
            "Review entries in Tajnica",
            "Review Entries",
            "Open Review"
        ]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSiriOpensCaptureTab() throws {
        try requireExplicitSiriUITestEnablement()

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Diary"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Diary"].tap()
        assertNavigationTitle("Diary", in: app)

        activateSiri(using: SiriPhrase.capture, expecting: "Capture", in: app)
    }

    @MainActor
    func testSiriOpensReviewTab() throws {
        try requireExplicitSiriUITestEnablement()

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Capture"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Capture"].tap()
        assertNavigationTitle("Capture", in: app)

        activateSiri(using: SiriPhrase.review, expecting: "Review", in: app)
    }

    @MainActor
    func testAlternateSiriPhraseReturnsToReviewFromAnotherTab() throws {
        try requireExplicitSiriUITestEnablement()

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Diary"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Diary"].tap()
        assertNavigationTitle("Diary", in: app)

        activateSiri(
            using: ["Review Entries", "Open Review in Tajnica s.p.", "Review entries in Tajnica"],
            expecting: "Review",
            in: app
        )
    }

    private func activateSiri(
        using phrases: [String],
        expecting navigationTitle: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for phrase in phrases {
            XCUIDevice.shared.siriService.activate(voiceRecognitionText: phrase)
            app.activate()
            if app.navigationBars[navigationTitle].waitForExistence(timeout: 5) {
                return
            }
        }

        XCTFail(
            "Siri did not navigate to \(navigationTitle) using any expected phrase: \(phrases.joined(separator: ", "))",
            file: file,
            line: line
        )
    }

    private func requireExplicitSiriUITestEnablement(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENABLE_SIRI_UI_TESTS"] == "1",
            "Siri UI smoke tests are opt-in because simulator phrase execution is not reliable under xcodebuild. Run them manually on device for release sign-off, or set ENABLE_SIRI_UI_TESTS=1 to experiment locally.",
            file: file,
            line: line
        )
    }

    private func assertNavigationTitle(
        _ title: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), file: file, line: line)
    }
    #endif
}

//
//  PackageSwitcherUITests.swift
//  PackageSwitcherUITests
//
//  Created by BlackRockCity on 7/2/24.
//

import XCTest

final class PackageSwitcherUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testModernSwitchingInterfaceIsVisible() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["appTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["currentManagerHeading"].exists)
        XCTAssertTrue(app.staticTexts["profileFileLabel"].exists)
        XCTAssertTrue(app.staticTexts["profilePathValue"].exists)
        XCTAssertTrue(app.buttons["homebrewCard"].exists)
        XCTAssertTrue(app.buttons["macPortsCard"].exists)
        XCTAssertTrue(app.buttons["applyButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["restartNotice"].exists)
        XCTAssertTrue(app.links["supportLink"].exists)
    }
}

import XCTest
@testable import Nodge

final class NodgeTests: XCTestCase {
    func testKeyboardShortcutParsing() {
        XCTAssertEqual(Keys.parse("cmd+shift+t")?.key, 17)
        XCTAssertNil(Keys.parse("cmd+definitely-not-a-key"))
    }

    func testSpokenURLsStayConservative() {
        XCTAssertEqual(Parse.url(from: "open github dot com")?.host, "github.com")
        XCTAssertNil(Parse.url(from: "open something with spaces"))
    }
}

import XCTest
import AppKit
@testable import Nodge

final class NodgeTests: XCTestCase {
    @MainActor
    func testPanelForwardsPasteAndSelectAllToFieldEditor() throws {
        _ = NSApplication.shared
        let panel = NodgePanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                               styleMask: [.borderless], backing: .buffered, defer: false)
        let editor = ClipboardFreeEditor(frame: panel.contentView!.bounds)
        panel.contentView = editor
        XCTAssertTrue(panel.makeFirstResponder(editor))
        func key(_ character: String, code: UInt16) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: .command, timestamp: 0, windowNumber: panel.windowNumber,
                context: nil, characters: character, charactersIgnoringModifiers: character,
                isARepeat: false, keyCode: code))
        }
        XCTAssertTrue(panel.performKeyEquivalent(with: try key("v", code: 9)))
        XCTAssertEqual(editor.string, "dummy-paste")
        XCTAssertTrue(panel.performKeyEquivalent(with: try key("a", code: 0)))
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 11))
        panel.close()
    }

    func testKeyboardShortcutParsing() {
        XCTAssertEqual(Keys.parse("cmd+shift+t")?.key, 17)
        XCTAssertNil(Keys.parse("cmd+definitely-not-a-key"))
    }

    func testSpokenURLsStayConservative() {
        XCTAssertEqual(Parse.url(from: "open github dot com")?.host, "github.com")
        XCTAssertNil(Parse.url(from: "open something with spaces"))
    }
}

private final class ClipboardFreeEditor: NSTextView {
    override func paste(_ sender: Any?) {
        insertText("dummy-paste", replacementRange: selectedRange())
    }
}

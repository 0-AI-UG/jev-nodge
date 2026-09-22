import XCTest
import AppKit
@testable import Nodge

final class NodgeTests: XCTestCase {
    func testEveryVisibleHUDStateClearsTheDisplayCutout() {
        let insetWithoutReportedSafeArea = HUDLayout.contentTopInset(safeAreaTop: 0, displayTopOverlap: 2)
        XCTAssertEqual(insetWithoutReportedSafeArea, HUDLayout.minimumContentTopInset)

        let insetForNotchedDisplay = HUDLayout.contentTopInset(safeAreaTop: 38, displayTopOverlap: 2)
        XCTAssertEqual(insetForNotchedDisplay, 44)
        for shape in [HUDModel.Shape.pill, .card, .setup] {
            XCTAssertGreaterThanOrEqual(
                HUDLayout.topPadding(for: shape, contentTopInset: insetForNotchedDisplay),
                insetForNotchedDisplay
            )
        }
    }

    func testPanelGrowsToPreserveContentAfterAddingCutoutClearance() {
        let safeInset: CGFloat = 44
        XCTAssertEqual(HUDLayout.panelSize(for: .pill, contentTopInset: safeInset).height, 162)
        XCTAssertEqual(HUDLayout.panelSize(for: .card, contentTopInset: safeInset).height, 271)
        XCTAssertEqual(HUDLayout.panelSize(for: .setup, contentTopInset: safeInset).height, 314)
    }

    func testAssistantLanguagesHaveStableLocalesAndPromptNames() {
        XCTAssertEqual(AssistantLanguage.german.localeIdentifier, "de-DE")
        XCTAssertEqual(AssistantLanguage.russian.promptName, "Russian")
        XCTAssertEqual(Set(AssistantLanguage.allCases.map(\.localeIdentifier)).count,
                       AssistantLanguage.allCases.count)
    }

    func testEveryAssistantLanguageHasEveryUIString() {
        for language in AssistantLanguage.allCases {
            for key in UIStringKey.allCases {
                XCTAssertFalse(language.text(key).isEmpty, "Missing \(key) in \(language)")
            }
        }
    }

    func testAudioLevelRejectsNoiseAndClampsSpeechRange() {
        XCTAssertEqual(AudioLevel.normalized(decibels: -60), 0)
        XCTAssertGreaterThan(AudioLevel.normalized(decibels: -24), 0.5)
        XCTAssertEqual(AudioLevel.normalized(decibels: 0), 1)
    }

    @MainActor
    func testFeedbackHasReadingTimeAndSpeechCanBeStopped() {
        XCTAssertGreaterThanOrEqual(Controller.resultDuration, 12_000_000_000)
        VoiceResponder.shared.stop()
        XCTAssertFalse(VoiceResponder.shared.isSpeaking)
    }
    func testWakeNameAloneAndCommands() {
        XCTAssertEqual(VoiceWake.command(in: "Hey Jev", name: "Jev"), "")
        XCTAssertEqual(VoiceWake.command(in: "HEY JEV, open Safari", name: "Jev"), "open Safari")
        XCTAssertEqual(VoiceWake.command(in: "Hey Captain Mark!", name: "Captain Mark"), "")
        XCTAssertNil(VoiceWake.command(in: "remarkable", name: "Mark"))
        XCTAssertNil(VoiceWake.command(in: "open Safari", name: "Jev"))
    }

    func testVoiceShortcutCaptureMatchingAndRoundTrip() throws {
        func event(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49))
        }
        let shortcut = try XCTUnwrap(VoiceShortcut(event: event(.option)))
        XCTAssertEqual(shortcut, .previousDefault)
        XCTAssertTrue(shortcut.matches(try event([.option, .capsLock])))
        XCTAssertFalse(shortcut.matches(try event([.option, .shift])))
        XCTAssertNil(VoiceShortcut(event: try event([])))
        XCTAssertEqual(try JSONDecoder().decode(VoiceShortcut.self, from: JSONEncoder().encode(shortcut)), shortcut)
    }

    func testFnOnlyTapIgnoresCombinationsAndRepeatedRelease() throws {
        func event(_ type: NSEvent.EventType, _ code: UInt16, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero,
                modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
        }
        var tap = FnTap()
        XCTAssertEqual(VoiceShortcut.standard.label, "Fn")
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, .function)))
        XCTAssertTrue(tap.consume(try event(.flagsChanged, 63, [])))
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, [])))
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, .function)))
        XCTAssertFalse(tap.consume(try event(.keyDown, 51, .function)))
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, [])))
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, [.function, .command])))
        XCTAssertFalse(tap.consume(try event(.flagsChanged, 63, .command)))
    }

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

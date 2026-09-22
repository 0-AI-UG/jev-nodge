import AppKit

struct VoiceShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    let label: String

    static let standard = VoiceShortcut(keyCode: 63, modifiers: NSEvent.ModifierFlags.function.rawValue, label: "Fn")
    static let previousDefault = VoiceShortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags.option.rawValue, label: "⌥ Space")
    var isFnOnly: Bool { keyCode == 63 && modifiers == NSEvent.ModifierFlags.function.rawValue }
    static let modifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    func matches(_ event: NSEvent) -> Bool {
        event.type == .keyDown && !isFnOnly && event.keyCode == keyCode && event.modifierFlags.intersection(Self.modifierMask).rawValue == modifiers
    }

    init(keyCode: UInt16, modifiers: UInt, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let flags = event.modifierFlags.intersection(Self.modifierMask)
        // Do not intercept unmodified typing.
        guard !flags.intersection([.command, .option, .control]).isEmpty,
              event.keyCode != 53,
              let character = event.charactersIgnoringModifiers, !character.isEmpty else { return nil }
        let key = event.keyCode == 49 ? "Space" : character.uppercased()
        guard key.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
        self.init(keyCode: event.keyCode, modifiers: flags.rawValue, label: prefix + " " + key)
    }
}

/// Trigger on release, only if Fn was not used with another key.
struct FnTap {
    private var pressed = false
    private var usedWithOtherKey = false

    mutating func consume(_ event: NSEvent) -> Bool {
        if event.type == .flagsChanged, event.keyCode == 63 {
            if event.modifierFlags.contains(.function) {
                if !pressed {
                    pressed = true
                    usedWithOtherKey = !event.modifierFlags.intersection(VoiceShortcut.modifierMask).isEmpty
                }
                return false
            }
            let tapped = pressed && !usedWithOtherKey
                && event.modifierFlags.intersection(VoiceShortcut.modifierMask).isEmpty
            pressed = false
            usedWithOtherKey = false
            return tapped
        }
        if pressed { usedWithOtherKey = true }
        return false
    }
}

enum VoiceWake {
    /// nil means no wake phrase; an empty string means the name alone was heard.
    static func command(in transcript: String, name: String) -> String? {
        let words = transcript.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let wake = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !wake.isEmpty, words.count >= wake.count else { return nil }
        for index in 0...(words.count - wake.count) {
            let matches = zip(words[index..<(index + wake.count)], wake).allSatisfy {
                $0.compare($1, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if matches {
                // Use token matching only to locate the phrase; retain punctuation in commands.
                let escaped = wake.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "[\\W_]+")
                if let range = transcript.range(of: "(?<![\\p{L}\\p{N}])" + escaped + "(?![\\p{L}\\p{N}])",
                                                options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
                    return String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                }
            }
        }
        return nil
    }
}

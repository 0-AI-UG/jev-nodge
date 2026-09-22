import Foundation
import Security

enum AssistantLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    case german = "de-DE"
    case russian = "ru-RU"
    case spanish = "es-ES"
    case french = "fr-FR"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case chinese = "zh-CN"
    case japanese = "ja-JP"

    static let defaultsKey = "assistantLanguage"

    var id: String { rawValue }
    var localeIdentifier: String { rawValue }

    var label: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .russian: return "Русский"
        case .spanish: return "Español"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        }
    }

    var promptName: String {
        switch self {
        case .english: return "English"
        case .german: return "German"
        case .russian: return "Russian"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Simplified Chinese"
        case .japanese: return "Japanese"
        }
    }

    static var saved: AssistantLanguage? {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey),
           let language = AssistantLanguage(rawValue: saved) {
            return language
        }
        return nil
    }

    static var savedOrSystemDefault: AssistantLanguage {
        if let saved { return saved }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return allCases.first { preferred.hasPrefix($0.rawValue.prefix(2).lowercased()) } ?? .english
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum ActivationMode: String, CaseIterable, Identifiable {
        case shortcut
        case wakePhrase

        var id: String { rawValue }
    }

    private enum Key {
        static let responseModel = "responseModel"
        static let jevModel = "jevModel"
        static let wakePhrase = "wakePhrase"
        static let setupComplete = "setupComplete"
        static let voiceShortcut = "voiceShortcut"
        static let activationMode = "activationMode"
    }

    @Published var responseModel: String
    @Published var jevModel: String
    @Published var wakePhrase: String {
        didSet { UserDefaults.standard.set(wakePhrase, forKey: Key.wakePhrase) }
    }
    @Published var voiceShortcut: VoiceShortcut {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(voiceShortcut), forKey: Key.voiceShortcut) }
    }
    @Published var activationMode: ActivationMode {
        didSet { UserDefaults.standard.set(activationMode.rawValue, forKey: Key.activationMode) }
    }
    @Published var assistantLanguage: AssistantLanguage {
        didSet { UserDefaults.standard.set(assistantLanguage.rawValue, forKey: AssistantLanguage.defaultsKey) }
    }
    @Published private(set) var setupComplete: Bool

    private init() {
        let defaults = UserDefaults.standard
        let savedShortcut = defaults.data(forKey: Key.voiceShortcut)
            .flatMap { try? JSONDecoder().decode(VoiceShortcut.self, from: $0) } ?? .standard
        voiceShortcut = savedShortcut == .previousDefault ? .standard : savedShortcut
        if savedShortcut == .previousDefault {
            defaults.set(try? JSONEncoder().encode(VoiceShortcut.standard), forKey: Key.voiceShortcut)
        }
        responseModel = defaults.string(forKey: Key.responseModel) ?? "~openai/gpt-latest"
        jevModel = defaults.string(forKey: Key.jevModel) ?? "~typesafe/jev-latest"
        wakePhrase = defaults.string(forKey: Key.wakePhrase) ?? "Jev"
        activationMode = ActivationMode(rawValue: defaults.string(forKey: Key.activationMode) ?? "") ?? .shortcut
        assistantLanguage = AssistantLanguage.savedOrSystemDefault
        setupComplete = defaults.bool(forKey: Key.setupComplete)
    }

    var openRouterKey: String? { Keychain.read("openrouter") ?? env["OPENROUTER_API_KEY"] }

    func save(openRouterKey replacementKey: String?) throws {
        let replacementKey = replacementKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let replacementKey, !replacementKey.isEmpty {
            try Keychain.write(replacementKey, account: "openrouter")
        } else if openRouterKey == nil {
            throw SettingsError("Add an OpenRouter API key")
        }
        let defaults = UserDefaults.standard
        defaults.set(responseModel, forKey: Key.responseModel)
        defaults.set(jevModel, forKey: Key.jevModel)
        defaults.set(wakePhrase, forKey: Key.wakePhrase)
        defaults.set(try JSONEncoder().encode(voiceShortcut), forKey: Key.voiceShortcut)
        defaults.set(activationMode.rawValue, forKey: Key.activationMode)
        defaults.set(assistantLanguage.rawValue, forKey: AssistantLanguage.defaultsKey)
        defaults.set(true, forKey: Key.setupComplete)
        setupComplete = true
    }

    func setActivationMode(_ mode: ActivationMode) {
        activationMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Key.activationMode)
    }

    func resetSetup() {
        UserDefaults.standard.set(false, forKey: Key.setupComplete)
        setupComplete = false
    }
}

struct SettingsError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

enum Keychain {
    private static let service = "ug.zeroai.nodge"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) throws {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes = [kSecValueData as String: Data(value.utf8)]
        let status: OSStatus
        if SecItemCopyMatching(lookup as CFDictionary, nil) == errSecSuccess {
            status = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        } else {
            status = SecItemAdd(lookup.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw SettingsError("Keychain could not save the credential (\(status))")
        }
    }
}

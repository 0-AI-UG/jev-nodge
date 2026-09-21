import Foundation
import Security

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let responseModel = "responseModel"
        static let jevModel = "jevModel"
        static let wakePhrase = "wakePhrase"
        static let voiceProvider = "voiceProvider"
        static let elevenLabsVoiceID = "elevenLabsVoiceID"
        static let setupComplete = "setupComplete"
    }

    @Published var responseModel: String
    @Published var jevModel: String
    @Published var wakePhrase: String
    @Published var voiceProvider: VoiceProvider
    @Published var elevenLabsVoiceID: String
    @Published private(set) var setupComplete: Bool

    enum VoiceProvider: String, CaseIterable, Identifiable {
        case system = "System voice"
        case elevenLabs = "ElevenLabs"

        var id: String { rawValue }
    }

    private init() {
        let defaults = UserDefaults.standard
        responseModel = defaults.string(forKey: Key.responseModel) ?? "~openai/gpt-latest"
        jevModel = defaults.string(forKey: Key.jevModel) ?? "~typesafe/jev-latest"
        wakePhrase = defaults.string(forKey: Key.wakePhrase) ?? "Jev"
        voiceProvider = VoiceProvider(rawValue: defaults.string(forKey: Key.voiceProvider) ?? "") ?? .system
        elevenLabsVoiceID = defaults.string(forKey: Key.elevenLabsVoiceID) ?? ""
        setupComplete = defaults.bool(forKey: Key.setupComplete) && Keychain.read("openrouter") != nil
    }

    var openRouterKey: String? { Keychain.read("openrouter") ?? env["OPENROUTER_API_KEY"] }
    var elevenLabsKey: String? { Keychain.read("elevenlabs") ?? env["ELEVENLABS_API_KEY"] }

    func save(openRouterKey: String, elevenLabsKey: String) throws {
        let openRouterKey = openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !openRouterKey.isEmpty else { throw SettingsError("Add an OpenRouter API key") }
        try Keychain.write(openRouterKey, account: "openrouter")
        if !elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try Keychain.write(elevenLabsKey, account: "elevenlabs")
        }
        let defaults = UserDefaults.standard
        defaults.set(responseModel, forKey: Key.responseModel)
        defaults.set(jevModel, forKey: Key.jevModel)
        defaults.set(wakePhrase, forKey: Key.wakePhrase)
        defaults.set(voiceProvider.rawValue, forKey: Key.voiceProvider)
        defaults.set(elevenLabsVoiceID, forKey: Key.elevenLabsVoiceID)
        defaults.set(true, forKey: Key.setupComplete)
        setupComplete = true
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

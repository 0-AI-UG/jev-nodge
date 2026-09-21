import AppKit
import AVFoundation

@MainActor
final class VoiceResponder: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceResponder()

    private let synthesizer = AVSpeechSynthesizer()
    private var sound: NSSound?

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        sound?.stop()
        if AppSettings.shared.voiceProvider == .elevenLabs,
           let key = AppSettings.shared.elevenLabsKey,
           !AppSettings.shared.elevenLabsVoiceID.isEmpty {
            Task { await speakWithElevenLabs(text, key: key, voiceID: AppSettings.shared.elevenLabsVoiceID) }
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    private func speakWithElevenLabs(_ text: String, key: String, voiceID: String) async {
        do {
            let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue(key, forHTTPHeaderField: "xi-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "text": text,
                "model_id": "eleven_multilingual_v2",
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let sound = NSSound(data: data) else {
                throw SettingsError("ElevenLabs did not return playable audio")
            }
            self.sound = sound
            sound.play()
        } catch {
            log("ElevenLabs voice failed: \(error.localizedDescription)")
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.5
            synthesizer.speak(utterance)
        }
    }
}

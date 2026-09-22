import AVFoundation
import MOSSTTSKit

@MainActor
final class VoiceResponder {
    static let shared = VoiceResponder()
    private static let preferredSpeakerIDs = ["Ava", "Bella", "Nathan", "Adam"]
    private static let playbackRate: Float = 1.14

    var onLevel: (Double) -> Void = { _ in }
    private var model: MOSSTTSKit?
    private var modelTask: Task<MOSSTTSKit, Error>?
    private var speechTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var playbackID = UUID()
    private(set) var isSpeaking = false

    private init() {}

    func stop() {
        playbackID = UUID()
        speechTask?.cancel()
        speechTask = nil
        stopAudio()
        isSpeaking = false
        onLevel(0)
    }

    func waitUntilFinished() async {
        while isSpeaking && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func prepare() {
        guard model == nil, modelTask == nil else { return }
        Task { [weak self] in
            _ = try? await self?.localModel()
        }
    }

    func speak(_ text: String) {
        stop()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let id = UUID()
        playbackID = id
        isSpeaking = true
        onLevel(0.12)

        speechTask = Task { [weak self] in
            guard let self else { return }
            do {
                let model = try await self.localModel()
                try Task.checkCancellation()
                let result = try await model.speak(
                    text: text,
                    speaker: await self.preferredSpeaker(
                        in: model,
                        language: AppSettings.shared.assistantLanguage
                    )
                )
                try Task.checkCancellation()
                guard self.playbackID == id else { return }
                try self.play(
                    samples: result.audioSamples,
                    sampleRate: result.sampleRate,
                    channels: result.channels,
                    id: id
                )
            } catch is CancellationError {
                self.finish(id: id)
            } catch {
                log("Local MOSS voice failed: \(error.localizedDescription)")
                self.finish(id: id)
            }
        }
    }

    private func preferredSpeaker(in model: MOSSTTSKit, language: AssistantLanguage) async -> MOSSSpeaker? {
        let speakers = await model.availableSpeakers
        let groupPrefix: String?
        switch language {
        case .chinese: groupPrefix = "Chinese"
        case .japanese: groupPrefix = "Japanese"
        default: groupPrefix = "English"
        }
        let matching = speakers.filter { $0.group?.hasPrefix(groupPrefix ?? "") == true }
        return Self.preferredSpeakerIDs.lazy.compactMap { preferredID in
            matching.first { $0.identifier == preferredID }
        }.first ?? matching.first ?? speakers.first
    }

    private func localModel() async throws -> MOSSTTSKit {
        if let model { return model }
        if let modelTask {
            let loaded = try await modelTask.value
            model = loaded
            return loaded
        }

        let task = Task<MOSSTTSKit, Error> {
            try await MOSSTTSKit(options: .init(
                autoDownload: true,
                progressCallback: { progress in
                    log("MOSS voice model: \(progress.description)")
                }
            ))
        }
        modelTask = task
        do {
            let loaded = try await task.value
            model = loaded
            modelTask = nil
            return loaded
        } catch {
            modelTask = nil
            throw error
        }
    }

    private func play(samples: [Float], sampleRate: Int, channels: Int, id: UUID) throws {
        guard !samples.isEmpty, channels > 0 else {
            finish(id: id)
            return
        }

        let channelCount = AVAudioChannelCount(channels)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Double(sampleRate),
            channels: channelCount
        ) else {
            throw VoiceError("Could not create the local voice audio format")
        }

        let frameCount = AVAudioFrameCount(samples.count / channels)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else {
            throw VoiceError("Could not create the local voice audio buffer")
        }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            for channel in 0..<channels {
                channelData[channel][frame] = samples[frame * channels + channel]
            }
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        varispeed.rate = Self.playbackRate
        engine.attach(player)
        engine.attach(varispeed)
        engine.connect(player, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: format
        ) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            var sum: Float = 0
            for frame in 0..<frames {
                let sample = data[0][frame]
                sum += sample * sample
            }
            let level = min(1, Double(sqrt(sum / Float(frames))) * 5.5)
            Task { @MainActor [weak self] in
                guard let self, self.playbackID == id else { return }
                self.onLevel(level)
            }
        }

        self.audioEngine = engine
        self.player = player
        try engine.start()
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finish(id: id) }
        }
        player.play()
    }

    private func finish(id: UUID) {
        guard playbackID == id else { return }
        stopAudio()
        speechTask = nil
        isSpeaking = false
        onLevel(0)
    }

    private func stopAudio() {
        player?.stop()
        if let mixer = audioEngine?.mainMixerNode {
            mixer.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        player = nil
        audioEngine = nil
    }
}

private struct VoiceError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

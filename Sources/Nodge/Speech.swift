import AVFoundation
import Speech

/// A microphone-only level meter for setup. It does not create a speech
/// recognizer or turn sound into commands.
@MainActor
final class SetupAudioMeter {
    var onLevel: (Double) -> Void = { _ in }
    private(set) var engine: AVAudioEngine?
    private var wantsRunning = false
    private var running = false

    func start() {
        wantsRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            Task { @MainActor in
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                guard granted, self.wantsRunning else { return }
                self.begin()
            }
        default:
            onLevel(0)
        }
    }

    func stop() {
        wantsRunning = false
        if let engine {
            engine.stop()
            if running { engine.inputNode.removeTap(onBus: 0) }
        }
        engine = nil
        running = false
        onLevel(0)
    }

    private func begin() {
        guard wantsRunning, !running else { return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            let level = min(1, AudioLevel.from(buffer) * 1.25)
            Task { @MainActor in self?.onLevel(level) }
        }
        engine.prepare()
        do {
            try engine.start()
            self.engine = engine
            running = true
        } catch {
            input.removeTap(onBus: 0)
            log("setup audio meter failed: \(error.localizedDescription)")
        }
    }
}

/// Always-on speech recognition. An utterance ends after a short silence; onFinal then fires with its text
/// and a fresh recognition session starts straight away.
@MainActor
final class Listener {
    var onPartial: (String) -> Void = { _ in }
    var onFinal: (String) -> Void = { _ in }
    var onLevel: (Double) -> Void = { _ in }
    private(set) var enabled = false

    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: Registry.locale))
    private(set) var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var last = ""

    static func requestPermissions(then done: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
                }
            }
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
            done()
        }
    }

    /// Called after a config reload: a new language needs a new recognizer.
    func applyConfig() {
        guard recognizer?.locale.identifier.replacingOccurrences(of: "_", with: "-") != Registry.locale else { return }
        log("recognition language → \(Registry.locale)")
        end()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: Registry.locale))
        begin()
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        log("listening \(on ? "on" : "paused")")
        if on { begin() } else { end() }
    }

    private func begin() {
        guard enabled, request == nil else { return }
        retryTask?.cancel()
        retryTask = nil
        last = ""
        guard let recognizer, recognizer.isAvailable,
              SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            retry(after: 5)
            return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            log("cannot listen: input=\(format.sampleRate)Hz")
            retry(after: 5)
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        let name = AppSettings.shared.wakePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        req.contextualStrings = [name, "Hey \(name)"]
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request = req
        self.engine = engine
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            let level = AudioLevel.from(buffer)
            Task { @MainActor in self?.onLevel(level) }
        }
        engine.prepare()
        do { try engine.start() } catch {
            log("audio engine failed: \(error)")
            end()
            retry(after: 5)
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let done = result?.isFinal == true || error != nil
            Task { @MainActor in
                guard let self, self.request === req else { return }
                // the on-device final result can come back empty; keep the last partial
                if let text, !text.isEmpty, text != self.last {
                    self.last = text
                    self.onPartial(text)
                    self.silenceTimer?.cancel()
                    self.silenceTimer = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Registry.silence * 1_000_000_000))  // no new words = end of utterance
                        if !Task.isCancelled { self.utteranceDone(req) }
                    }
                }
                if done { self.utteranceDone(req) }  // also the recognizer's own "no speech" timeouts: just restart
            }
        }
    }

    private func utteranceDone(_ req: SFSpeechAudioBufferRecognitionRequest) {
        guard request === req else { return }
        let text = last
        end()
        if text.isEmpty {
            retry(after: 0.3)
        } else {
            log("heard: “\(text)”")
            onFinal(text)
            begin()
        }
    }

    private func end() {
        retryTask?.cancel()
        retryTask = nil
        silenceTimer?.cancel()
        silenceTimer = nil
        request?.endAudio()
        request = nil
        // Never access inputNode on an idle engine: doing so creates audio I/O.
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        task?.cancel()
        task = nil
        onLevel(0)
    }

    private func retry(after seconds: Double) {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            catch { return }
            self?.begin()
        }
    }
}

enum AudioLevel {
    /// Maps a practical speech range onto 0...1 while rejecting ordinary room noise.
    static func normalized(decibels: Float) -> Double {
        let linear = min(1, max(0, Double((decibels + 52) / 44)))
        return linear * linear * (3 - 2 * linear)
    }

    static func from(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = Int(buffer.frameLength)
        let channelCount = max(1, Int(buffer.format.channelCount))
        var sum: Float = 0
        if buffer.format.isInterleaved {
            let samples = channels[0]
            for sample in 0..<(frames * channelCount) { sum += samples[sample] * samples[sample] }
        } else {
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in 0..<frames { sum += samples[frame] * samples[frame] }
            }
        }
        let rms = sqrt(sum / Float(frames * channelCount))
        return normalized(decibels: 20 * log10(max(rms, 0.000_001)))
    }
}

import SwiftUI

@MainActor
final class HUDModel: ObservableObject {
    enum Shape { case hidden, pill, card, setup }

    @Published var shape: Shape = .hidden
    @Published var title = "Listening"
    @Published var subtitle = ""
    @Published var hint = ""
    @Published var probs: [Double] = []
    @Published var pulse = false
    @Published var setupError = ""
    @Published var openRouterKey = ""
    @Published var elevenLabsKey = ""
    var onSetupComplete: (() -> Void)?

    func show(_ shape: Shape, title: String, subtitle: String = "", hint: String = "", probs: [Double] = []) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            self.shape = shape
            self.title = title
            self.subtitle = subtitle
            self.hint = hint
            self.probs = probs
        }
    }

    func hide() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { shape = .hidden }
    }

    func confirm() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { self.pulse = false }
    }

    func finishSetup() {
        do {
            try AppSettings.shared.save(openRouterKey: openRouterKey, elevenLabsKey: elevenLabsKey)
            setupError = ""
            onSetupComplete?()
        } catch {
            setupError = error.localizedDescription
        }
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(spacing: 0) {
            switch model.shape {
            case .hidden:
                Color.clear.frame(width: 210, height: 12)
            case .pill:
                CompactView(model: model)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .card:
                ResultView(model: model)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .setup:
                SetupView(model: model)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: model.shape)
    }
}

private struct CompactView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        HStack(spacing: 11) {
            ListeningBars(active: model.title.localizedCaseInsensitiveContains("listen"))
            Text(model.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 6)
            Circle()
                .fill(model.title.localizedCaseInsensitiveContains("listen") ? Color.green : Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(width: 350, height: 54)
        .nodgeSurface(cornerRadius: 22)
    }
}

private struct ResultView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                Text(model.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                ConfidenceDots(values: model.probs)
            }
            if !model.subtitle.isEmpty {
                Text(model.subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.hint.isEmpty {
                Text(model.hint)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(width: 460, alignment: .topLeading)
        .frame(minHeight: 118, alignment: .topLeading)
        .nodgeSurface(cornerRadius: 28)
        .scaleEffect(model.pulse ? 1.015 : 1, anchor: .top)
    }
}

private struct SetupView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set up Nodge")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Voice in. Jev decides. Your Mac acts.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
            }

            VStack(spacing: 12) {
                FieldRow(title: "OpenRouter key", systemImage: "key.fill") {
                    SecureField("sk-or-v1-…", text: $model.openRouterKey)
                        .textFieldStyle(.plain)
                }
                Divider().overlay(.white.opacity(0.08))
                FieldRow(title: "Wake phrase", systemImage: "ear") {
                    TextField("Nodge", text: $settings.wakePhrase)
                        .textFieldStyle(.plain)
                }
                Divider().overlay(.white.opacity(0.08))
                FieldRow(title: "Jev model", systemImage: "point.3.connected.trianglepath.dotted") {
                    TextField("~typesafe/jev-latest", text: $settings.jevModel)
                        .textFieldStyle(.plain)
                }
                Divider().overlay(.white.opacity(0.08))
                FieldRow(title: "Answer model", systemImage: "text.bubble.fill") {
                    TextField("~openai/gpt-latest", text: $settings.responseModel)
                        .textFieldStyle(.plain)
                }
            }
            .padding(15)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Picker("Voice", selection: $settings.voiceProvider) {
                    ForEach(AppSettings.VoiceProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                if settings.voiceProvider == .elevenLabs {
                    HStack(spacing: 10) {
                        SecureField("ElevenLabs key", text: $model.elevenLabsKey)
                        TextField("Voice ID", text: $settings.elevenLabsVoiceID)
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }

            if !model.setupError.isEmpty {
                Label(model.setupError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            HStack {
                Link("Create an OpenRouter key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button(action: model.finishSetup) {
                    HStack(spacing: 7) {
                        Text("Start Nodge")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(width: 520)
        .nodgeSurface(cornerRadius: 32)
    }
}

private struct FieldRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 102, alignment: .leading)
            content
                .font(.system(size: 12.5, design: .monospaced))
        }
    }
}

private struct ListeningBars: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .frame(width: 2.5, height: active ? 6 + 8 * abs(sin(phase * 4 + Double(index))) : 6)
                }
            }
        }
        .frame(width: 18, height: 18)
        .foregroundStyle(.white.opacity(0.8))
    }
}

private struct ConfidenceDots: View {
    let values: [Double]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(values.sorted(by: >).prefix(5).enumerated()), id: \.offset) { _, value in
                Circle()
                    .fill(.white.opacity(0.18 + value * 0.82))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

private extension View {
    func nodgeSurface(cornerRadius: CGFloat) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.94))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.16))
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.42), radius: 22, y: 12)
    }
}

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
    @Published var setupStep = 0
    @Published var openRouterKey = ""
    @Published var elevenLabsKey = ""
    var onSetupComplete: (() -> Void)?
    var onShapeChange: ((Shape) -> Void)?

    func show(_ shape: Shape, title: String, subtitle: String = "", hint: String = "", probs: [Double] = []) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            self.shape = shape
            self.title = title
            self.subtitle = subtitle
            self.hint = hint
            self.probs = probs
        }
        onShapeChange?(shape)
    }

    func hide() {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.7)) { shape = .hidden }
        onShapeChange?(.hidden)
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

    func advanceSetup() {
        setupError = ""
        switch setupStep {
        case 0:
            guard !AppSettings.shared.wakePhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                setupError = "Choose a wake name"
                return
            }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep = 1 }
        case 1:
            guard !openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                setupError = "Add an OpenRouter API key"
                return
            }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep = 2 }
        default:
            finishSetup()
        }
    }

    func retreatSetup() {
        guard setupStep > 0 else { return }
        setupError = ""
        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep -= 1 }
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
                    .padding(.bottom, 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .card:
                ResultView(model: model)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .setup:
                SetupView(model: model)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.48, dampingFraction: 0.68), value: model.shape)
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
                .fill(model.title.localizedCaseInsensitiveContains("listen") ? Color.white : Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(width: 350, height: 54)
        .nodgeSurface(bottomRadius: 16)
    }
}

private struct ResultView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
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
        .nodgeSurface(bottomRadius: 18)
        .scaleEffect(model.pulse ? 1.015 : 1, anchor: .top)
    }
}

private struct SetupView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            Text(stepTitle)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 29)

            Text(stepSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.top, 3)

            StepDots(current: model.setupStep)
                .padding(.top, 7)

            ZStack {
                stepContent
                    .id(model.setupStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(height: 70)
            .clipped()

            Text(model.setupError)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .frame(height: 12)
                .opacity(model.setupError.isEmpty ? 0 : 1)

            HStack(spacing: 12) {
                if model.setupStep > 0 {
                    Button("Back", action: model.retreatSetup)
                        .buttonStyle(SecondarySetupButtonStyle())
                }
                Button(model.setupStep == 2 ? "Start" : "Continue", action: model.advanceSetup)
                    .buttonStyle(PrimarySetupButtonStyle())
            }
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .frame(width: 330, height: 220)
        .animatedNodgeSurface(bottomRadius: 18)
        .animation(.spring(response: 0.46, dampingFraction: 0.78), value: model.setupStep)
    }

    private var stepTitle: String {
        switch model.setupStep {
        case 0: return "Wake Jev Nodge"
        case 1: return "Connect OpenRouter"
        default: return "Choose a voice"
        }
    }

    private var stepSubtitle: String {
        switch model.setupStep {
        case 0: return "Pick a short name that feels natural to say."
        case 1: return "Your key stays in the macOS Keychain."
        default: return "Jev Nodge will speak AI answers using this voice."
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.setupStep {
        case 0:
            HStack(spacing: 10) {
                Text("Hey")
                    .foregroundStyle(.white.opacity(0.42))
                TextField("Jev", text: $settings.wakePhrase)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 170)
            }
            .font(.system(size: 13.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .setupField()
        case 1:
            VStack(spacing: 6) {
                SecureField("sk-or-v1-…", text: $model.openRouterKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .setupField()
                Link("Create an OpenRouter key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        default:
            VStack(spacing: 6) {
                Picker("Voice", selection: $settings.voiceProvider) {
                    ForEach(AppSettings.VoiceProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                if settings.voiceProvider == .elevenLabs {
                    HStack(spacing: 8) {
                        SecureField("ElevenLabs key", text: $model.elevenLabsKey)
                        TextField("Voice ID", text: $settings.elevenLabsVoiceID)
                    }
                    .textFieldStyle(.roundedBorder)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

            }
        }
    }
}

private struct StepDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == current ? .white : .white.opacity(0.18))
                    .frame(width: index == current ? 14 : 4, height: 4)
            }
        }
    }
}

private struct PrimarySetupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .frame(minWidth: 86)
            .frame(height: 30)
            .background(.white.opacity(configuration.isPressed ? 0.76 : 1), in: Capsule())
            .foregroundStyle(.black)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct SecondarySetupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .frame(minWidth: 60)
            .frame(height: 30)
            .background(.white.opacity(configuration.isPressed ? 0.13 : 0.07), in: Capsule())
            .foregroundStyle(.white.opacity(0.72))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
    func setupField() -> some View {
        background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 0.7)
            }
    }

    func nodgeSurface(bottomRadius: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: bottomRadius,
                bottomTrailing: bottomRadius,
                topTrailing: 0
            ),
            style: .continuous
        )
        return background {
            ZStack {
                shape.fill(.black)
                LinearGradient(
                    colors: [.black, .black, .white.opacity(0.045)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
            }
        }
        .overlay {
            shape.strokeBorder(.white.opacity(0.07), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }

    func animatedNodgeSurface(bottomRadius: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: bottomRadius,
                bottomTrailing: bottomRadius,
                topTrailing: 0
            ),
            style: .continuous
        )
        return background {
            shape.fill(.black)
        }
        .overlay {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 20
                let gradient = AngularGradient(
                    colors: [.blue, .purple, .pink, .orange, .cyan, .blue],
                    center: .center,
                    startAngle: .degrees(phase),
                    endAngle: .degrees(phase + 360)
                )
                ZStack {
                    shape.strokeBorder(gradient, lineWidth: 12)
                        .blur(radius: 7)
                        .opacity(0.58)
                    shape.strokeBorder(gradient, lineWidth: 1.5)
                        .opacity(0.9)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
    }
}

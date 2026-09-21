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
                .padding(.top, 22)

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
            .frame(height: 56)
            .clipped()

            if !model.setupError.isEmpty {
                Text(model.setupError)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(height: 11)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if model.setupStep > 0 {
                    Button("Back", action: model.retreatSetup)
                        .buttonStyle(SecondarySetupButtonStyle())
                }
                Button(model.setupStep == 2 ? "Start" : "Continue", action: model.advanceSetup)
                    .buttonStyle(PrimarySetupButtonStyle())
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .frame(width: 330, height: 180)
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
            .frame(height: 32)
            .setupField()
        case 1:
            VStack(spacing: 6) {
                SecureField("sk-or-v1-…", text: $model.openRouterKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
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
            .frame(height: 28)
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
            .frame(height: 28)
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

/// A white source splits into animated spectral plumes above the bottom edge.
private struct PrismaticGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let breath = 0.85 + 0.15 * sin(time * 1.6)
                let center = size.width * (0.5 + 0.065 * sin(time * 0.9))
                let span = size.width * (0.40 + 0.035 * sin(time * 1.2))

                func ribbon(_ color: Color, offset: Double, width: Double, blur: Double, opacity: Double) {
                    var path = Path()
                    for index in 0...96 {
                        let u = Double(index) / 96
                        let x = center + (u * 2 - 1) * span
                        let envelope = pow(sin(u * .pi), 2)
                        let flare = sin(u * .pi * 4 - time * 2.2 + offset * 0.17)
                        let wave = 1.2 + max(0, offset) * 0.65 * flare
                        let y = size.height - 1.8 - envelope * (wave + offset)
                        let point = CGPoint(x: x, y: y)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    var layer = context
                    layer.addFilter(.blur(radius: blur))
                    layer.opacity = opacity * breath
                    layer.stroke(path, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: color.opacity(0.35), location: 0.18),
                            .init(color: color, location: 0.5),
                            .init(color: color.opacity(0.35), location: 0.82),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: CGPoint(x: center - span, y: 0),
                        endPoint: CGPoint(x: center + span, y: 0)
                    ), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }

                // Screen blending retains saturation as the colored plumes overlap.
                context.blendMode = .screen
                ribbon(Color(red: 0.65, green: 0.04, blue: 1), offset: 16, width: 12, blur: 7, opacity: 0.65)
                ribbon(Color(red: 1, green: 0.06, blue: 0.32), offset: 12, width: 7, blur: 3.5, opacity: 0.85)
                ribbon(Color(red: 1, green: 0.56, blue: 0.05), offset: 8, width: 5, blur: 2.5, opacity: 0.8)
                ribbon(Color(red: 0.02, green: 0.85, blue: 1), offset: 4.5, width: 5, blur: 2.5, opacity: 0.95)
                ribbon(Color(red: 0.16, green: 0.2, blue: 1), offset: 2, width: 7, blur: 4, opacity: 0.8)
                ribbon(.white, offset: 0, width: 4, blur: 3, opacity: 0.6)
                ribbon(.white, offset: 0, width: 1.5, blur: 0.7, opacity: 0.95)
            }
        }
        .frame(height: 42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
            ZStack(alignment: .bottom) {
                shape.fill(.black)
                PrismaticGlow()
            }
            .clipShape(shape)
        }
        .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
    }
}

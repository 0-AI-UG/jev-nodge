import SwiftUI

enum HUDLayout {
    /// A fixed fallback keeps content clear of the camera housing when macOS
    /// does not report a safe-area inset, as can happen while displays change.
    static let minimumContentTopInset: CGFloat = 34
    private static let cameraClearance: CGFloat = 4

    static func contentTopInset(safeAreaTop: CGFloat, displayTopOverlap: CGFloat) -> CGFloat {
        max(
            minimumContentTopInset,
            ceil(max(0, safeAreaTop) + max(0, displayTopOverlap) + cameraClearance)
        )
    }

    static func topPadding(for shape: HUDModel.Shape, contentTopInset: CGFloat) -> CGFloat {
        switch shape {
        case .hidden: 0
        case .pill, .card: max(minimumContentTopInset, contentTopInset)
        case .setup: max(56, contentTopInset)
        }
    }

    static func panelSize(for shape: HUDModel.Shape, contentTopInset: CGFloat) -> CGSize {
        let baseSize: CGSize
        let previousTopPadding: CGFloat
        switch shape {
        case .hidden:
            return CGSize(width: 390, height: 12)
        case .pill:
            (baseSize, previousTopPadding) = (CGSize(width: 410, height: 150), 32)
        case .card:
            (baseSize, previousTopPadding) = (CGSize(width: 430, height: 245), 18)
        case .setup:
            (baseSize, previousTopPadding) = (CGSize(width: 390, height: 314), 56)
        }
        let addedClearance = max(0, topPadding(for: shape, contentTopInset: contentTopInset) - previousTopPadding)
        return CGSize(width: baseSize.width, height: baseSize.height + addedClearance)
    }
}

@MainActor
final class HUDModel: ObservableObject {
    enum Shape { case hidden, pill, card, setup }

    @Published var shape: Shape = .hidden
    @Published var title = "Listening"
    @Published var subtitle = ""
    @Published var transcript = ""
    @Published var hint = ""
    @Published var probs: [Double] = []
    @Published var pulse = false
    @Published private(set) var audioLevel = 0.0
    @Published var setupError = ""
    @Published var setupStep = 0
    @Published var recordingShortcut = false
    @Published var openRouterKey = ""
    @Published private(set) var hasStoredOpenRouterKey = false
    @Published private(set) var contentTopInset = HUDLayout.minimumContentTopInset
    private var audioTarget = 0.0
    private var audioSmoothingTask: Task<Void, Never>?
    var onSetupComplete: (() -> Void)?
    var onShapeChange: ((Shape) -> Void)?

    func updateContentTopInset(_ inset: CGFloat) {
        contentTopInset = inset
    }

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
        audioTarget = 0
        audioSmoothingTask?.cancel()
        audioSmoothingTask = nil
        withAnimation(.spring(response: 0.46, dampingFraction: 0.7)) {
            shape = .hidden
            audioLevel = 0
        }
        onShapeChange?(.hidden)
    }

    func beginInput() {
        transcript = ""
    }

    func updateTranscript(_ text: String) {
        transcript = text
    }

    func setAudioLevel(_ level: Double) {
        audioTarget = min(1, max(0, level))
        guard audioSmoothingTask == nil else { return }
        audioSmoothingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let difference = self.audioTarget - self.audioLevel
                if abs(difference) < 0.001 {
                    self.audioLevel = self.audioTarget
                } else {
                    // A fixed-rate envelope prevents irregular microphone callbacks
                    // from directly retargeting SwiftUI animations and flickering.
                    let response = difference > 0 ? 0.07 : 0.045
                    self.audioLevel += difference * response
                }
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    func confirm() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { self.pulse = false }
    }

    func finishSetup() {
        do {
            let replacementKey = openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try AppSettings.shared.save(openRouterKey: replacementKey.isEmpty ? nil : replacementKey)
            hasStoredOpenRouterKey = true
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
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep = 1 }
        case 1:
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep = 2 }
        case 2:
            guard AppSettings.shared.activationMode != .wakePhrase ||
                    !AppSettings.shared.wakePhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                AppSettings.shared.wakePhrase = ""
                setupError = AppSettings.shared.assistantLanguage.text(.chooseWakeName)
                return
            }
            recordingShortcut = false
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep = 3 }
        case 3:
            guard hasStoredOpenRouterKey || !openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                openRouterKey = ""
                setupError = AppSettings.shared.assistantLanguage.text(.addOpenRouterKey)
                return
            }
            finishSetup()
        default:
            break
        }
    }

    func retreatSetup() {
        recordingShortcut = false
        guard setupStep > 0 else { return }
        setupError = ""
        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) { setupStep -= 1 }
    }

    func prepareSetup() {
        openRouterKey = ""
        hasStoredOpenRouterKey = AppSettings.shared.openRouterKey != nil
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
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))
            case .card:
                ResultView(model: model)
                    .padding(.bottom, 28)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))
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
            ListeningBars(active: model.title.localizedCaseInsensitiveContains("listen"), level: model.audioLevel)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(1)
                if !model.transcript.isEmpty {
                    Text(model.transcript)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 6)
            Circle()
                .fill(model.title.localizedCaseInsensitiveContains("listen") ? Color.white : Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, HUDLayout.topPadding(for: .pill, contentTopInset: model.contentTopInset))
        .padding(.bottom, 14)
        .frame(width: 350)
        .frame(minHeight: 86)
        .nodgeSurface(bottomRadius: 16, audioLevel: model.audioLevel)
    }
}

private struct ResultView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)
                Text(model.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                ConfidenceDots(values: model.probs)
                    .padding(.top, 7)
                    .fixedSize()
            }
            if !model.transcript.isEmpty {
                Text(model.transcript)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
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
        .padding(.horizontal, 20)
        .padding(.top, HUDLayout.topPadding(for: .card, contentTopInset: model.contentTopInset))
        .padding(.bottom, 18)
        .frame(width: 390, alignment: .topLeading)
        .frame(minHeight: 108, alignment: .topLeading)
        .nodgeSurface(bottomRadius: 16, audioLevel: model.audioLevel)
        .scaleEffect(model.pulse ? 1.015 : 1, anchor: .top)
    }
}

private struct SetupView: View {
    @ObservedObject var model: HUDModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            Text(stepTitle)
                .font(.system(size: 15.5, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .bottom)
                .padding(.horizontal, 8)
                .padding(.top, HUDLayout.topPadding(for: .setup, contentTopInset: model.contentTopInset))

            Text(stepSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .top)
                .padding(.top, 3)

            StepDots(current: model.setupStep)
                .padding(.top, 7)

            ZStack {
                stepContent
                    .id(model.setupStep)
                    .transition(.asymmetric(
                        insertion: .offset(x: 12).combined(with: .opacity),
                        removal: .offset(x: -12).combined(with: .opacity)
                    ))
            }
            .frame(height: 76)

            if model.setupStep == 3 && !model.setupError.isEmpty {
                Text(model.setupError)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(height: 11)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if model.setupStep > 0 {
                    Button(action: model.retreatSetup) {
                        Image(systemName: "chevron.left")
                            .frame(width: 12, height: 16)
                            .accessibilityLabel(settings.assistantLanguage.text(.back))
                    }
                    .help(settings.assistantLanguage.text(.back))
                    .modifier(SetupButtonAppearance(primary: false))
                }
                Button(action: model.advanceSetup) {
                    Text(settings.assistantLanguage.text(model.setupStep == 3 ? .startButton : .continueButton))
                        .frame(height: 16)
                }
                .modifier(SetupButtonAppearance(primary: true))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 22)
        .frame(width: 330, height: 250)
        .nodgeSurface(bottomRadius: 18, audioLevel: model.audioLevel)
        .animation(.spring(response: 0.46, dampingFraction: 0.78), value: model.setupStep)
        .onChange(of: settings.wakePhrase) { _, value in
            if model.setupStep == 2 && !value.isEmpty { model.setupError = "" }
        }
        .onChange(of: model.openRouterKey) { _, value in
            if model.setupStep == 3 && !value.isEmpty { model.setupError = "" }
        }
    }

    private var stepTitle: String {
        switch model.setupStep {
        case 0: return settings.assistantLanguage.text(.assistantLanguage)
        case 1: return settings.assistantLanguage.text(.voiceActivation)
        case 2: return settings.assistantLanguage.text(.voiceShortcut)
        default: return settings.assistantLanguage.text(.connectOpenRouter)
        }
    }

    private var stepSubtitle: String {
        switch model.setupStep {
        case 0: return settings.assistantLanguage.text(.languageSubtitle)
        case 1: return settings.activationMode == .shortcut
            ? settings.assistantLanguage.text(.microphoneOff)
            : settings.assistantLanguage.text(.wakeActive)
        case 2: return settings.assistantLanguage.text(.shortcutSubtitle)
        default: return settings.assistantLanguage.text(.connectSubtitle)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.setupStep {
        case 0:
            HStack(spacing: 0) {
                Button {
                    moveLanguage(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 40, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.assistantLanguage.text(.previousLanguage))

                Text(settings.assistantLanguage.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())

                Button {
                    moveLanguage(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 40, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.assistantLanguage.text(.nextLanguage))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .setupField()
        case 1:
            ActivationModeControl(selection: $settings.activationMode, language: settings.assistantLanguage)
        case 2:
            HStack(spacing: 8) {
                if settings.activationMode == .wakePhrase {
                    HStack(spacing: 9) {
                        Text("Hey")
                            .foregroundStyle(.white.opacity(0.42))
                        TextField(settings.assistantLanguage.text(.wakeName), text: $settings.wakePhrase,
                                  prompt: Text(model.setupError.isEmpty ? "Jev" : model.setupError)
                                    .foregroundStyle(.white.opacity(0.6)))
                            .accessibilityLabel(settings.assistantLanguage.text(.wakeName))
                            .accessibilityHint(model.setupError)
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .setupField()
                }

                Button {
                    model.recordingShortcut.toggle()
                } label: {
                    Text(model.recordingShortcut ? "Press…" : settings.voiceShortcut.label)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .setupField()
                }
                .frame(
                    minWidth: settings.activationMode == .wakePhrase ? 82 : 0,
                    maxWidth: settings.activationMode == .wakePhrase ? 82 : .infinity
                )
                .buttonStyle(.plain)
                .accessibilityLabel("Record voice shortcut")
            }
        case 3:
            SecureField(settings.assistantLanguage.text(.addOpenRouterKey), text: $model.openRouterKey,
                        prompt: Text(model.setupError.isEmpty
                            ? (model.hasStoredOpenRouterKey ? "••••••••••••" : "sk-or-v1-…")
                            : model.setupError)
                            .foregroundStyle(.white.opacity(0.6)))
                .accessibilityLabel(settings.assistantLanguage.text(.addOpenRouterKey))
                .accessibilityHint(model.setupError)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .setupField()
        default:
            EmptyView()
        }
    }

    private func moveLanguage(by offset: Int) {
        let languages = AssistantLanguage.allCases
        guard let current = languages.firstIndex(of: settings.assistantLanguage) else { return }
        settings.assistantLanguage = languages[(current + offset + languages.count) % languages.count]
    }
}

private struct ActivationModeControl: View {
    @Binding var selection: AppSettings.ActivationMode
    let language: AssistantLanguage

    var body: some View {
        HStack(spacing: 3) {
            option(.shortcut, title: language.text(.shortcutOnly))
            option(.wakePhrase, title: language.text(.wakePhrase))
        }
        .padding(3)
        .frame(height: 40)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.6)
        }
        .accessibilityElement(children: .contain)
    }

    private func option(_ mode: AppSettings.ActivationMode, title: String) -> some View {
        let selected = selection == mode
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = mode
            }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.58))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.20), .white.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(.white.opacity(0.20), lineWidth: 0.6)
                            }
                            .shadow(color: .black.opacity(0.4), radius: 5, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct StepDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == current ? .white : .white.opacity(0.18))
                    .frame(width: index == current ? 14 : 4, height: 4)
            }
        }
    }
}

private struct SetupButtonAppearance: ViewModifier {
    let primary: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if primary {
                content.buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
            } else {
                content.buttonStyle(.glass)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
            }
        } else {
            content.buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

private struct ListeningBars: View {
    let active: Bool
    let level: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let voice = level * (0.72 + 0.28 * abs(sin(phase * 7 + Double(index) * 1.7)))
                    Capsule()
                        .frame(width: 2.5, height: active ? 5 + 11 * max(voice, 0.12) : 6)
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
    let level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                PrismaticGlowRenderer.draw(
                    in: context,
                    size: size,
                    level: level,
                    time: time,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(height: 42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct NodgeSideAndBottomOutline: Shape {
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = 0.3
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let bottom = rect.maxY - inset
        let radius = min(bottomRadius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: bottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: left + radius, y: bottom),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: right - radius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: right, y: bottom - radius),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY))
        return path
    }
}

private extension View {
    func setupField() -> some View {
        background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.06), .white.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.6)
            }
    }

    func nodgeSurface(bottomRadius: CGFloat, audioLevel: Double) -> some View {
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
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(.regular.tint(.black.opacity(0.45)), in: shape)
                } else {
                    shape.fill(.ultraThinMaterial)
                        .overlay(shape.fill(.black.opacity(0.4)))
                }
                // Opaque near the camera, translucent toward the lower glass lip.
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.16),
                    .init(color: .black.opacity(0.85), location: 0.38),
                    .init(color: .black.opacity(0.25), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                PrismaticGlow(level: audioLevel)
            }
            .clipShape(shape)
            .environment(\.colorScheme, .dark)
        }
        .overlay(alignment: .top) {
            Color.black
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .overlay {
            NodgeSideAndBottomOutline(bottomRadius: bottomRadius)
                .stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 0.6, lineCap: .butt))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
    }
}

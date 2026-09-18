import SwiftUI

/// The thing the Watch is driving, with a mode switcher above it and a
/// readout below that doubles as a test pad for swiping without a Watch.
struct StageView: View {
    @Environment(SwipeHub.self) private var hub

    var body: some View {
        VStack(spacing: 0) {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            FlickReadout()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: Binding(
                    get: { hub.mode },
                    set: { hub.setMode($0) }
                )) {
                    ForEach(Mode.allCases) { mode in
                        Image(systemName: mode.symbolName)
                            .accessibilityLabel(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .modifier(KeepAwake())
    }

    @ViewBuilder
    private var modeContent: some View {
        switch hub.mode {
        case .reader: ReaderView()
        case .photos: PhotosView()
        case .slides: SlidesView()
        case .prompter: PrompterView()
        }
    }
}

/// The last flick and what it did, plus the current mode's legend. Dragging
/// or tapping on it sends a phone-sourced flick through the same pipeline.
struct FlickReadout: View {
    @Environment(SwipeHub.self) private var hub
    private let classifier = SwipeClassifier()

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: hub.lastReceived?.event.direction.symbolName ?? "hand.draw")
                    .font(.title3.weight(.bold))
                    .frame(width: 28)
                    .symbolEffect(.bounce, value: hub.pulse)
                VStack(alignment: .leading, spacing: 1) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            legend
        }
        .contentShape(Rectangle())
        .gesture(localDrag)
        .onTapGesture {
            hub.handle(SwipeEvent(direction: .tap, source: .phone))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Test pad. \(headline). \(detail)")
        .accessibilityActions {
            ForEach(SwipeDirection.allCases, id: \.self) { direction in
                Button(hub.context.label(for: direction) ?? direction.title) {
                    hub.handle(SwipeEvent(direction: direction, source: .phone))
                }
            }
        }
    }

    private var headline: String {
        if let last = hub.lastReceived {
            return "\(last.event.direction.title) from \(last.event.source.title): \(last.action)"
        }
        return "Waiting for a flick"
    }

    private var detail: String {
        guard let last = hub.lastReceived else { return "Flick on the Watch, or swipe here" }
        var parts: [String] = [last.receivedAt.formatted(date: .omitted, time: .standard)]
        if last.event.source == .watch { parts.append("\(Int(last.latency * 1000)) ms") }
        if last.event.speed > 0 { parts.append("\(Int(last.event.speed)) pt/s") }
        return parts.joined(separator: "  ·  ")
    }

    private var legend: some View {
        HStack(spacing: 0) {
            ForEach(SwipeDirection.allCases, id: \.self) { direction in
                VStack(spacing: 3) {
                    Image(systemName: direction.symbolName)
                        .font(.caption.weight(.semibold))
                    Text(hub.context.label(for: direction) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var localDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                guard let reading = classifier.classify(
                    translation: value.translation,
                    predictedEnd: value.predictedEndTranslation,
                    velocity: value.velocity
                ) else { return }
                hub.handle(SwipeEvent(direction: reading.direction,
                                      distance: reading.distance,
                                      speed: reading.speed,
                                      source: .phone))
            }
    }
}

/// A propped-up phone must not sleep while a mode is on screen.
private struct KeepAwake: ViewModifier {
    @Environment(SwipeHub.self) private var hub

    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = hub.settings.keepAwake }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: hub.settings.keepAwake) { _, keep in
                UIApplication.shared.isIdleTimerDisabled = keep
            }
    }
}

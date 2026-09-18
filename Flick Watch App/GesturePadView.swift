import SwiftUI
import WatchKit

/// The whole screen is the control surface. Flick anywhere; the phone reacts.
/// The edges are labelled with what each direction does right now, the crown
/// scrolls, Double Tap selects, and a long press picks the mode.
struct GesturePadView: View {
    @Environment(WatchLink.self) private var link
    @AppStorage("watch.haptics") private var haptics = true

    @State private var flash: SwipeDirection?
    @State private var flashCount = 0
    @State private var flashTask: Task<Void, Never>?
    @State private var showModes = false
    @State private var crown = 0.0
    @State private var lastCrown = 0.0

    private let classifier = SwipeClassifier()

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    statusLine
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 6)

                edgeLegend

                if let flash {
                    Image(systemName: flash.symbolName)
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                        .id(flashCount)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(drag)
            .onTapGesture { fire(.tap, distance: 0, speed: 0) }
            .onLongPressGesture(minimumDuration: 0.6) { showModes = true }
            .focusable()
            .digitalCrownRotation($crown, from: 0, through: 1000, by: 1, sensitivity: .medium,
                                  isContinuous: true, isHapticFeedbackEnabled: false)
            .onChange(of: crown) { _, value in
                // Continuous mode wraps at the ends; a jump of hundreds is a wrap, not a turn.
                let delta = value - lastCrown
                lastCrown = value
                if abs(delta) < 500 { link.crown(delta) }
            }
            .sheet(isPresented: $showModes) {
                NavigationStack { ModeSheet() }
            }
            .toolbar(.hidden, for: .navigationBar)
            #if DEBUG
            .task { await runScript() }
            #endif
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                guard let reading = classifier.classify(
                    translation: value.translation,
                    predictedEnd: value.predictedEndTranslation,
                    velocity: value.velocity
                ) else { return }
                fire(reading.direction, distance: reading.distance, speed: reading.speed)
            }
    }

    private func fire(_ direction: SwipeDirection, distance: CGFloat, speed: CGFloat) {
        if haptics { link.haptic(for: direction) }
        link.send(SwipeEvent(direction: direction, distance: distance, speed: speed, source: .watch))

        flashCount += 1
        withAnimation(.spring(duration: 0.22, bounce: 0.35)) {
            flash = direction
        }
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { flash = nil }
        }
    }

    #if DEBUG
    /// The Watch simulator returns to its clock face 15 seconds after the last
    /// touch and nothing scripted counts as a touch, so this starts the moment
    /// the session is reachable and keeps the spacing short.
    private func runScript() async {
        let script = DebugFlicks.scripted
        let mode = DebugFlicks.mode
        guard !script.isEmpty || mode != nil else { return }
        for _ in 0..<60 where !link.isReachable {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if let mode {
            link.setMode(mode)
            try? await Task.sleep(for: .milliseconds(400))
        }
        for direction in script {
            fire(direction, distance: 80, speed: 900)
            try? await Task.sleep(for: .milliseconds(350))
        }
    }
    #endif

    // MARK: Pieces

    private var context: PhoneContext? { link.phoneContext }

    private var background: some View {
        LinearGradient(
            colors: link.isReachable
                ? [Color(red: 0.16, green: 0.20, blue: 0.62), Color(red: 0.07, green: 0.08, blue: 0.24)]
                : [Color(white: 0.22), Color(white: 0.08)],
            startPoint: .top, endPoint: .bottom
        )
    }

    @ViewBuilder
    private var header: some View {
        if let context {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: context.mode.symbolName)
                    Text(context.mode.title.uppercased())
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 4) {
                    if let badge = context.badge {
                        Image(systemName: badge)
                            .foregroundStyle(badge.hasPrefix("star") ? .yellow : .white)
                    }
                    Text(context.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if !context.subtitle.isEmpty {
                    Text(context.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Text(link.isReachable ? "Flick to control" : "Open the app on iPhone")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    /// What each direction will do, placed at the edge it belongs to. The
    /// centre is a real button so Double Tap can trigger it.
    private var edgeLegend: some View {
        ZStack {
            VStack {
                edgeLabel(.up)
                Spacer()
                edgeLabel(.down)
            }
            .padding(.top, 54)
            .padding(.bottom, 22)
            HStack {
                edgeLabel(.right)
                Spacer()
                edgeLabel(.left)
            }
            .padding(.horizontal, 6)
            Button {
                fire(.tap, distance: 0, speed: 0)
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "hand.tap")
                    Text(context?.label(for: .tap) ?? "Tap")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(8)
            }
            .offset(y: 18)
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)
            .accessibilityLabel("Tap: \(context?.label(for: .tap) ?? "select")")
        }
        .allowsHitTesting(true)
        .accessibilityActions {
            ForEach(SwipeDirection.allCases, id: \.self) { direction in
                Button(context?.label(for: direction) ?? direction.title) {
                    fire(direction, distance: 80, speed: 900)
                }
            }
        }
    }

    private func edgeLabel(_ direction: SwipeDirection) -> some View {
        Group {
            if let label = context?.label(for: direction) {
                VStack(spacing: 0) {
                    Image(systemName: direction.symbolName)
                        .font(.system(size: 9, weight: .bold))
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: 62)
            }
        }
        .allowsHitTesting(false)
    }

    private var statusLine: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(link.isReachable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if link.sentCount + link.queuedCount > 0 {
                Text("\(link.sentCount + link.queuedCount)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        if let error = link.lastError, !link.isReachable {
            return error
        }
        if link.isReachable {
            if let rtt = link.lastRoundTrip {
                return "\(Int(rtt * 1000)) ms"
            }
            return "Connected"
        }
        if !link.isActivated {
            return "Starting"
        }
        return link.queuedCount > 0 ? "Queued \(link.queuedCount)" : "Phone away"
    }
}

#Preview {
    GesturePadView()
        .environment(WatchLink())
}

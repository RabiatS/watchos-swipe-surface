import SwiftUI
import WatchKit

/// The whole screen is the control surface. Flick anywhere; the phone reacts.
struct GesturePadView: View {
    @Environment(WatchLink.self) private var link

    @State private var flash: SwipeDirection?
    @State private var flashCount = 0
    @State private var flashTask: Task<Void, Never>?

    private let classifier = SwipeClassifier()

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 6) {
                contextLabel
                Spacer(minLength: 0)
                statusLine
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if let flash {
                Image(systemName: flash.symbolName)
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                    .id(flashCount)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onTapGesture { fire(.tap, distance: 0, speed: 0) }
        #if DEBUG
        .task { await runScriptedFlicks() }
        #endif
    }

    #if DEBUG
    /// The Watch simulator returns to its clock face 15 seconds after the last
    /// touch and nothing scripted counts as a touch, so this starts the moment
    /// the session is reachable and keeps the spacing short.
    private func runScriptedFlicks() async {
        let script = DebugFlicks.scripted
        guard !script.isEmpty else { return }
        for _ in 0..<60 where !link.isReachable {
            try? await Task.sleep(for: .milliseconds(50))
        }
        for direction in script {
            fire(direction, distance: 80, speed: 900)
            try? await Task.sleep(for: .milliseconds(350))
        }
    }
    #endif

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
        link.haptic(for: direction)
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

    // MARK: Pieces

    private var background: some View {
        LinearGradient(
            colors: link.isReachable
                ? [Color(red: 0.16, green: 0.20, blue: 0.62), Color(red: 0.07, green: 0.08, blue: 0.24)]
                : [Color(white: 0.22), Color(white: 0.08)],
            startPoint: .top, endPoint: .bottom
        )
    }

    @ViewBuilder
    private var contextLabel: some View {
        if let context = link.phoneContext, context.count > 0 {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if context.isStarred {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                    }
                    Text(context.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text("\(context.index) of \(context.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            Text(link.isReachable ? "Flick to control" : "Open Flick on iPhone")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var statusLine: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(link.isReachable ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if link.sentCount + link.queuedCount > 0 {
                Text("\(link.sentCount + link.queuedCount)")
                    .font(.caption2.monospacedDigit())
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

import SwiftUI

/// The thing the Watch is driving. Cards slide the way they were flicked,
/// and a swipe on the card itself goes down the same path for testing.
struct DeckView: View {
    @Environment(SwipeHub.self) private var hub

    @State private var nudge: CGSize = .zero
    private let classifier = SwipeClassifier()

    var body: some View {
        VStack(spacing: 20) {
            stage
                .frame(maxHeight: .infinity)

            lastFlickBadge

            legend
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
        .onChange(of: hub.pulse) { _, _ in
            if hub.deck.bounced { bounce(hub.deck.lastMove) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Undo dismiss", systemImage: "arrow.uturn.backward") {
                        withAnimation(.spring(duration: 0.4)) { hub.undoDismiss() }
                    }
                    .disabled(hub.deck.dismissals.isEmpty)
                    Button("Reset deck", systemImage: "arrow.counterclockwise") {
                        withAnimation(.spring(duration: 0.4)) { hub.resetDeck() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: Stage

    @ViewBuilder
    private var stage: some View {
        ZStack {
            if let card = hub.deck.current {
                CardView(card: card,
                         isStarred: hub.deck.isCurrentStarred,
                         isFlipped: hub.deck.isFlipped)
                    .id(card.id)
                    .transition(slide)
                    .offset(nudge)
                    .contentShape(Rectangle())
                    .gesture(localDrag)
                    .onTapGesture {
                        hub.handle(SwipeEvent(direction: .tap, source: .phone))
                    }
            } else {
                ContentUnavailableView {
                    Label("Deck empty", systemImage: "rectangle.stack.badge.minus")
                } description: {
                    Text("Every card was dismissed. Undo or reset from the menu.")
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: hub.deck.current?.id)
        .overlay(alignment: .top) {
            if !hub.deck.cards.isEmpty {
                Text("\(hub.deck.index + 1) of \(hub.deck.cards.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    /// New card enters from the side it was flicked toward.
    private var slide: AnyTransition {
        switch hub.deck.lastMove {
        case .left:
            .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity))
        case .right:
            .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity))
        case .down:
            .asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity))
        default:
            .scale(scale: 0.95).combined(with: .opacity)
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

    /// A flick with nowhere to go still gets a visible reply.
    private func bounce(_ direction: SwipeDirection?) {
        let push: CGSize = switch direction {
        case .left: CGSize(width: -18, height: 0)
        case .right: CGSize(width: 18, height: 0)
        case .up: CGSize(width: 0, height: -14)
        case .down: CGSize(width: 0, height: 14)
        default: .zero
        }
        withAnimation(.spring(duration: 0.18, bounce: 0.6)) { nudge = push }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { nudge = .zero }
        }
    }

    // MARK: Badge and legend

    private var lastFlickBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: hub.lastDirection?.symbolName ?? "hand.draw")
                .font(.title2.weight(.bold))
                .frame(width: 32)
                .symbolEffect(.bounce, value: hub.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text(hub.received.first.map { "\($0.event.direction.title) from \($0.event.source.title)" }
                     ?? "Waiting for a flick")
                    .font(.subheadline.weight(.semibold))
                Text(hub.received.first.map(detail) ?? "Swipe on the Watch, or on the card")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detail(_ swipe: ReceivedSwipe) -> String {
        var parts = [swipe.event.direction.action]
        if swipe.event.source == .watch {
            parts.append("\(Int(swipe.latency * 1000)) ms")
        }
        if swipe.event.speed > 0 {
            parts.append("\(Int(swipe.event.speed)) pt/s")
        }
        return parts.joined(separator: "  ·  ")
    }

    private var legend: some View {
        HStack(spacing: 0) {
            ForEach(SwipeDirection.allCases, id: \.self) { direction in
                VStack(spacing: 4) {
                    Image(systemName: direction.symbolName)
                        .font(.footnote.weight(.semibold))
                    Text(shortAction(direction))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    private func shortAction(_ direction: SwipeDirection) -> String {
        switch direction {
        case .left: "Next"
        case .right: "Back"
        case .up: "Star"
        case .down: "Dismiss"
        case .tap: "Flip"
        }
    }
}

#Preview {
    NavigationStack {
        DeckView()
    }
    .environment(SwipeHub())
}

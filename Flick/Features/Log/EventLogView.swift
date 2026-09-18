import SwiftUI

/// Every flick that landed, newest first, with how long it took to arrive.
struct EventLogView: View {
    @Environment(SwipeHub.self) private var hub

    var body: some View {
        List {
            Section {
                LabeledContent("Flicks from Watch", value: "\(hub.watchEventCount)")
                LabeledContent("Mean latency",
                               value: hub.meanWatchLatency.map { "\(Int($0 * 1000)) ms" } ?? "n/a")
            }

            Section("Events") {
                if hub.received.isEmpty {
                    Text("Nothing yet. Flick on the Watch.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hub.received) { swipe in
                        row(swipe)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", systemImage: "trash") { hub.clearLog() }
                    .disabled(hub.received.isEmpty)
            }
        }
    }

    private func row(_ swipe: ReceivedSwipe) -> some View {
        HStack(spacing: 12) {
            Image(systemName: swipe.event.direction.symbolName)
                .font(.body.weight(.semibold))
                .frame(width: 24)
                .foregroundStyle(swipe.event.source == .watch ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(swipe.event.direction.title)
                    .font(.body.weight(.medium))
                Text(subtitle(swipe))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(swipe.event.source.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(swipe.event.source == .watch ? Color.accentColor : Color.secondary)
                if swipe.event.source == .watch {
                    Text("\(Int(swipe.latency * 1000)) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func subtitle(_ swipe: ReceivedSwipe) -> String {
        let time = swipe.receivedAt.formatted(date: .omitted, time: .standard)
        if swipe.event.speed > 0 {
            return "\(time)  ·  \(Int(swipe.event.distance)) pt  ·  \(Int(swipe.event.speed)) pt/s"
        }
        return time
    }
}

#Preview {
    NavigationStack {
        EventLogView()
    }
    .environment(SwipeHub())
}

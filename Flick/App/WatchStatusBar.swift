import SwiftUI

/// One line that says whether a flick on the wrist would land here right now.
struct WatchStatusBar: View {
    @Environment(SwipeHub.self) private var hub

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch")
                .foregroundStyle(tint)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var state: PhoneLink.State { hub.link.state }

    private var tint: Color {
        if !hub.link.isSupported || !state.isPaired { return .gray }
        if !state.isWatchAppInstalled { return .orange }
        return state.isReachable ? .green : .yellow
    }

    private var message: String {
        if !hub.link.isSupported { return "Watch link not available on this device" }
        if !state.isActivated { return "Connecting to Watch" }
        if !state.isPaired { return "No Apple Watch paired" }
        if !state.isWatchAppInstalled { return "Install Flick on the Watch to begin" }
        if state.isReachable { return "Watch is live. Flick anywhere on it." }
        return "Open Flick on the Watch to connect"
    }
}

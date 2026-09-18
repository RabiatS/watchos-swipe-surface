import SwiftUI

/// Three things to know, once. The pairing check is live so the last line
/// changes as soon as the Watch app is installed.
struct OnboardingView: View {
    @Environment(SwipeHub.self) private var hub
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("Your wrist drives this screen")
                    .font(.largeTitle.weight(.bold))
            }

            point("hand.draw", "Flick anywhere on the Watch",
                  "Up, down, left, right or tap. The Watch shows what each one will do in the current mode.")
            point("rectangle.stack", "Four things to drive",
                  "A reader for recipes and scores, a photo set, a slide deck, and a teleprompter.")
            point("iphone.gen3", "Prop the phone up",
                  "The screen stays awake while a mode is showing. Turn that off in Settings.")

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(hub.link.state.isWatchAppInstalled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(hub.link.state.isWatchAppInstalled
                     ? "The Watch app is installed."
                     : "Install the Watch app from the Watch app on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                hub.settings.hasOnboarded = true
                dismiss()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .interactiveDismissDisabled()
    }

    private func point(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

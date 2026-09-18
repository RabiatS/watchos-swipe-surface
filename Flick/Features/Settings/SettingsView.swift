import SwiftUI

struct SettingsView: View {
    @Environment(SwipeHub.self) private var hub

    var body: some View {
        @Bindable var settings = hub.settings
        Form {
            Section {
                Toggle("Keep screen awake", isOn: $settings.keepAwake)
                Toggle("Reverse left and right", isOn: $settings.reverseHorizontal)
            } header: {
                Text("Control")
            } footer: {
                Text("Keep awake stops the phone sleeping while a mode is on screen. Reverse makes a left flick mean previous, like pulling a page toward you.")
            }

            Section("Reader") {
                LabeledContent("Text size") {
                    Slider(value: $settings.readerTextSize, in: 14...40, step: 1)
                        .frame(width: 160)
                }
            }

            Section("Prompter") {
                LabeledContent("Text size") {
                    Slider(value: $settings.prompterTextSize, in: 20...60, step: 1)
                        .frame(width: 160)
                }
                Toggle("Mirror for glass", isOn: $settings.prompterMirror)
            }

            Section {
                LabeledContent("Watch", value: watchStatus)
                LabeledContent("Version", value: version)
                Button("Show welcome again") { settings.hasOnboarded = false }
            } header: {
                Text("About")
            } footer: {
                Text("Nothing leaves the phone. Imported files are copied into the app and can be replaced from each mode's menu.")
            }
        }
    }

    private var watchStatus: String {
        let s = hub.link.state
        if !hub.link.isSupported { return "Not available" }
        if !s.isPaired { return "Not paired" }
        if !s.isWatchAppInstalled { return "App not installed" }
        return s.isReachable ? "Connected" : "Not reachable"
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

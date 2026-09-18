import SwiftUI

/// Reached by a long press on the pad. Picks what the phone shows, and holds
/// the one Watch-side setting.
struct ModeSheet: View {
    @Environment(WatchLink.self) private var link
    @Environment(\.dismiss) private var dismiss
    @AppStorage("watch.haptics") private var haptics = true

    var body: some View {
        List {
            Section("Phone shows") {
                ForEach(Mode.allCases) { mode in
                    Button {
                        link.setMode(mode)
                        dismiss()
                    } label: {
                        HStack {
                            Label(mode.title, systemImage: mode.symbolName)
                            Spacer()
                            if link.phoneContext?.mode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            Section {
                Toggle("Haptics", isOn: $haptics)
            }
        }
        .navigationTitle("Mode")
    }
}

import SwiftUI

struct RootView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var selection: Screen = initialScreen

    enum Screen: Hashable { case deck, log }

    private static var initialScreen: Screen {
        #if DEBUG
        DebugRoute.initialTab == .log ? .log : .deck
        #else
        .deck
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Deck", systemImage: "rectangle.stack", value: Screen.deck) {
                NavigationStack {
                    DeckView()
                        .safeAreaInset(edge: .top, spacing: 0) { WatchStatusBar() }
                        .navigationTitle("Flick")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            Tab("Log", systemImage: "list.bullet.rectangle", value: Screen.log) {
                NavigationStack {
                    EventLogView()
                        .safeAreaInset(edge: .top, spacing: 0) { WatchStatusBar() }
                        .navigationTitle("Log")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(SwipeHub())
}

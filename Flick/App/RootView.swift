import SwiftUI

struct RootView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var selection: Screen = initialScreen
    @State private var showOnboarding = false

    enum Screen: Hashable { case stage, log, settings }

    private static var initialScreen: Screen {
        #if DEBUG
        switch DebugRoute.initialTab {
        case .stage: .stage
        case .log: .log
        case .settings: .settings
        }
        #else
        .stage
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Stage", systemImage: "rectangle.inset.filled.and.person.filled", value: Screen.stage) {
                NavigationStack {
                    StageView()
                        .safeAreaInset(edge: .top, spacing: 0) { WatchStatusBar() }
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
            Tab("Settings", systemImage: "gearshape", value: Screen.settings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            #if DEBUG
            if let mode = DebugRoute.initialMode { hub.setMode(mode) }
            if DebugRoute.skipsOnboarding { hub.settings.hasOnboarded = true }
            #endif
            showOnboarding = !hub.settings.hasOnboarded
        }
        .onChange(of: hub.settings.hasOnboarded) { _, done in
            showOnboarding = !done
        }
    }
}

#Preview {
    RootView()
        .environment(SwipeHub())
}

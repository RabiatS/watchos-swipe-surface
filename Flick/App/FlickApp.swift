import SwiftUI

@main
struct FlickApp: App {
    @State private var hub: SwipeHub

    init() {
        #if DEBUG
        DebugRoute.resetIfAsked()
        #endif
        _hub = State(initialValue: SwipeHub())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(hub)
        }
    }
}

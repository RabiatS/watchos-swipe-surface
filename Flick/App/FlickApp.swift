import SwiftUI

@main
struct FlickApp: App {
    @State private var hub = SwipeHub()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(hub)
        }
    }
}

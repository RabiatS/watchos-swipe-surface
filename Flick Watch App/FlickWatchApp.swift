import SwiftUI

@main
struct FlickWatchApp: App {
    @State private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            GesturePadView()
                .environment(link)
        }
    }
}

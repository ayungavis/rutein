import RuteinKit
import SwiftUI

@main
struct RuteinApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}

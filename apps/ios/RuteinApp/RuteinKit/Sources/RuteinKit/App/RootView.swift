import SwiftUI

public struct RootView: View {
    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var body: some View {
        NavigationStack {
            RouteLibraryView(container: container)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    RootView(container: AppContainer.preview())
}

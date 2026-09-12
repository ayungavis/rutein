import SwiftUI

public struct RootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Your routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            } description: {
                Text("Import a GPX file to explore distance, elevation, and checkpoints.")
            }
            .navigationTitle("Rutein")
        }
    }
}

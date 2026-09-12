import SwiftUI

public struct RootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("library.empty.title", bundle: .module)
                } icon: {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                }
            } description: {
                Text("library.empty.description", bundle: .module)
            }
            .navigationTitle(Text(verbatim: "Rutein"))
        }
    }
}

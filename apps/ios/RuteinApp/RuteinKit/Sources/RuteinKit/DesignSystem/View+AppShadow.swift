import SwiftUI

public extension View {
    func appShadow() -> some View {
        shadow(color: .black.opacity(0.02), radius: 7.5, x: 0, y: 8)
    }
}

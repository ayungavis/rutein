public struct RouteSummary: Sendable, Equatable {
    public let distanceMetres: Double

    public init(distanceMetres: Double) {
        self.distanceMetres = distanceMetres
    }
}

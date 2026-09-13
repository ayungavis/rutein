public struct RouteSummary: Sendable, Equatable {
    public let distanceMetres: Double
    public let elevationCoverage: ElevationCoverage
    public let ascentMetres: Double?
    public let descentMetres: Double?
    public let minimumElevationMetres: Double?
    public let maximumElevationMetres: Double?

    public init(
        distanceMetres: Double,
        elevationCoverage: ElevationCoverage,
        ascentMetres: Double?,
        descentMetres: Double?,
        minimumElevationMetres: Double?,
        maximumElevationMetres: Double?,
    ) {
        self.distanceMetres = distanceMetres
        self.elevationCoverage = elevationCoverage
        self.ascentMetres = ascentMetres
        self.descentMetres = descentMetres
        self.minimumElevationMetres = minimumElevationMetres
        self.maximumElevationMetres = maximumElevationMetres
    }
}

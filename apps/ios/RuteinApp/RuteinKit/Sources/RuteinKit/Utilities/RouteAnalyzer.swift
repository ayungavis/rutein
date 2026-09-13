public enum RouteAnalyzer {
    @concurrent
    public static func analyse(_ geometry: RouteGeometry) async throws -> RouteSummary {
        var distance = 0.0

        for segment in geometry.segments {
            for index in segment.indices.dropLast() {
                distance += Haversine.metres(from: segment[index], to: segment[index + 1])
            }
        }

        guard distance > 0 else {
            throw AppError.geometry
        }

        let elevation = ElevationAnalysis.of(geometry)

        return RouteSummary(
            distanceMetres: distance,
            elevationCoverage: elevation.coverage,
            ascentMetres: elevation.ascentMetres,
            descentMetres: elevation.descentMetres,
            minimumElevationMetres: elevation.minimumMetres,
            maximumElevationMetres: elevation.maximumMetres,
        )
    }
}

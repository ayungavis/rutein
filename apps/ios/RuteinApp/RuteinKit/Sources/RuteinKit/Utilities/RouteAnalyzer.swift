public enum RouteAnalyzer {
    @concurrent
    public static func analyse(_ geometry: RouteGeometry) async throws -> RouteSummary {
        var total = 0.0

        for segment in geometry.segments {
            for index in segment.indices.dropLast() {
                total += Haversine.metres(from: segment[index], to: segment[index + 1])
            }
        }

        guard total > 0 else {
            throw AppError.geometry
        }

        return RouteSummary(distanceMetres: total)
    }
}

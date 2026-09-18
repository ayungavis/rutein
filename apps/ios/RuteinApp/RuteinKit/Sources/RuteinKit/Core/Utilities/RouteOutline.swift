public enum RouteOutline {
    public static let pointBudget = 64

    public static func points(from geometry: RouteGeometry) -> [RouteOutlinePoint] {
        let coordinates = RouteRegion.coordinates(from: geometry)

        guard coordinates.count > pointBudget else {
            return coordinates.map { RouteOutlinePoint(latitude: $0.latitude, longitude: $0.longitude) }
        }

        let stride = Double(coordinates.count - 1) / Double(pointBudget - 1)

        return (0 ..< pointBudget).map { step in
            let coordinate = coordinates[min(coordinates.count - 1, Int((Double(step) * stride).rounded()))]

            return RouteOutlinePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

import Foundation

public enum CheckpointAssociation {
    public static let maximumMatchMetres = 100.0
    public static let distinctProjectionMetres = 100.0
    public static let markerIntervalMetres = 5000.0

    private struct Projection {
        let routeDistanceMetres: Double
        let offsetMetres: Double
        let elevationMetres: Double?
    }

    public static func checkpoints(
        in geometry: RouteGeometry,
        totalDistanceMetres: Double,
    ) -> CheckpointSet {
        var matched: [Checkpoint] = []
        var unassociated: [String] = []
        var ambiguous: [String] = []

        for waypoint in geometry.waypoints {
            switch match(waypoint, in: geometry) {
            case let .matched(checkpoint): matched.append(checkpoint)
            case .ambiguous: ambiguous.append(waypoint.name)
            case .unassociated: unassociated.append(waypoint.name)
            }
        }

        let ordered = matched.isEmpty
            ? markers(in: geometry, totalDistanceMetres: totalDistanceMetres)
            : matched.sorted { $0.distanceMetres < $1.distanceMetres }

        return CheckpointSet(
            checkpoints: numbered(ordered),
            unassociated: unassociated,
            ambiguous: ambiguous,
        )
    }

    static func markers(in geometry: RouteGeometry, totalDistanceMetres: Double) -> [Checkpoint] {
        guard totalDistanceMetres > markerIntervalMetres else {
            return []
        }

        return stride(
            from: markerIntervalMetres,
            to: totalDistanceMetres,
            by: markerIntervalMetres,
        ).map { distance in
            let height = RoutePosition.elevation(at: distance, in: geometry)

            return Checkpoint(
                id: 0,
                name: nil,
                distanceMetres: distance,
                elevationMetres: height,
                origin: .distanceMarker,
                elevationSource: height == nil ? .unavailable : .geometry,
            )
        }
    }

    private enum Match {
        case matched(Checkpoint)
        case ambiguous
        case unassociated
    }

    private static func match(_ waypoint: Waypoint, in geometry: RouteGeometry) -> Match {
        let plausible = projections(of: waypoint, in: geometry)
            .filter { $0.offsetMetres <= maximumMatchMetres }

        guard let nearest = plausible.min(by: { $0.offsetMetres < $1.offsetMetres }) else {
            return .unassociated
        }

        guard clusterCount(plausible) == 1 else {
            return .ambiguous
        }

        let source: CheckpointElevationSource = if waypoint.elevation != nil {
            .waypoint
        } else if nearest.elevationMetres != nil {
            .geometry
        } else {
            .unavailable
        }

        return .matched(
            Checkpoint(
                id: 0,
                name: waypoint.name,
                distanceMetres: nearest.routeDistanceMetres,
                elevationMetres: waypoint.elevation ?? nearest.elevationMetres,
                origin: .waypoint,
                elevationSource: source,
            ),
        )
    }

    private static func clusterCount(_ projections: [Projection]) -> Int {
        let distances = projections.map(\.routeDistanceMetres).sorted()

        guard let first = distances.first else {
            return 0
        }

        var count = 1
        var previous = first

        for distance in distances.dropFirst() where distance - previous > distinctProjectionMetres {
            count += 1
            previous = distance
        }

        return count
    }

    private static func projections(of waypoint: Waypoint, in geometry: RouteGeometry) -> [Projection] {
        var travelled = 0.0
        var found: [Projection] = []

        for segment in geometry.segments {
            for index in segment.indices.dropFirst() {
                let edge = (start: segment[index - 1], end: segment[index])
                let length = Haversine.metres(from: edge.start, to: edge.end)

                found.append(project(waypoint, onto: edge, length: length, startDistance: travelled))
                travelled += length
            }
        }

        return found
    }

    private static func project(
        _ waypoint: Waypoint,
        onto edge: (start: TrackPoint, end: TrackPoint),
        length: Double,
        startDistance: Double,
    ) -> Projection {
        let metresPerDegree = Haversine.earthRadiusMetres * .pi / 180
        let cosLatitude = cos(edge.start.latitude * .pi / 180)

        func local(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
            (
                x: Haversine.normalisedDegrees(longitude - edge.start.longitude)
                    * cosLatitude * metresPerDegree,
                y: (latitude - edge.start.latitude) * metresPerDegree,
            )
        }

        let end = local(latitude: edge.end.latitude, longitude: edge.end.longitude)
        let point = local(latitude: waypoint.latitude, longitude: waypoint.longitude)
        let lengthSquared = end.x * end.x + end.y * end.y
        let along = lengthSquared > 0
            ? min(1, max(0, (point.x * end.x + point.y * end.y) / lengthSquared))
            : 0
        let closest = (x: end.x * along, y: end.y * along)
        let offset = ((point.x - closest.x) * (point.x - closest.x)
            + (point.y - closest.y) * (point.y - closest.y)).squareRoot()

        return Projection(
            routeDistanceMetres: startDistance + length * along,
            offsetMetres: offset,
            elevationMetres: interpolatedElevation(edge, along: along),
        )
    }

    private static func interpolatedElevation(
        _ edge: (start: TrackPoint, end: TrackPoint),
        along: Double,
    ) -> Double? {
        guard let start = edge.start.elevation, let end = edge.end.elevation else {
            return nil
        }

        return start + (end - start) * along
    }

    private static func numbered(_ checkpoints: [Checkpoint]) -> [Checkpoint] {
        checkpoints.enumerated().map { offset, checkpoint in
            Checkpoint(
                id: offset,
                name: checkpoint.name,
                distanceMetres: checkpoint.distanceMetres,
                elevationMetres: checkpoint.elevationMetres,
                origin: checkpoint.origin,
                elevationSource: checkpoint.elevationSource,
            )
        }
    }
}

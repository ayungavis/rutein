public enum RouteSourceKind: String, Sendable, Equatable, Codable {
    case track
    case route
}

public struct RouteCandidate: Identifiable, Sendable, Equatable {
    public let id: Int
    public let kind: RouteSourceKind
    public let name: String?
    public let segments: [[TrackPoint]]

    public init(id: Int, kind: RouteSourceKind, name: String?, segments: [[TrackPoint]]) {
        self.id = id
        self.kind = kind
        self.name = name
        self.segments = segments
    }

    public var usableSegments: [[TrackPoint]] {
        segments.filter { $0.count >= 2 }
    }

    public var isUsable: Bool {
        !usableSegments.isEmpty
    }

    public var pointCount: Int {
        segments.reduce(0) { $0 + $1.count }
    }
}

public struct GPXDocument: Sendable, Equatable {
    public let candidates: [RouteCandidate]
    public let waypoints: [Waypoint]

    public init(candidates: [RouteCandidate], waypoints: [Waypoint]) {
        self.candidates = candidates
        self.waypoints = waypoints
    }

    public var usable: [RouteCandidate] {
        candidates.filter(\.isUsable)
    }

    public var preferred: [RouteCandidate] {
        let tracks = usable.filter { $0.kind == .track }

        return tracks.isEmpty ? usable : tracks
    }

    public func geometry(for candidate: RouteCandidate) -> RouteGeometry {
        RouteGeometry(segments: candidate.usableSegments, waypoints: waypoints)
    }
}

public enum GPXLimits {
    public static let maximumGeometryPoints = 100_000
    public static let maximumWaypoints = 1000
}

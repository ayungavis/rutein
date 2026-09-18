public struct RouteGeometry: Sendable, Equatable {
    public let segments: [[TrackPoint]]
    public let waypoints: [Waypoint]

    public init(segments: [[TrackPoint]], waypoints: [Waypoint] = []) {
        self.segments = segments
        self.waypoints = waypoints
    }

    public var pointCount: Int {
        segments.reduce(0) { $0 + $1.count }
    }
}

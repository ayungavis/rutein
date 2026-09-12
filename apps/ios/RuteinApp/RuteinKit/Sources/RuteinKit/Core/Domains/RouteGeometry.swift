public struct RouteGeometry: Sendable, Equatable {
    public let segments: [[TrackPoint]]

    public init(segments: [[TrackPoint]]) {
        self.segments = segments
    }

    public var pointCount: Int {
        segments.reduce(0) { $0 + $1.count }
    }
}

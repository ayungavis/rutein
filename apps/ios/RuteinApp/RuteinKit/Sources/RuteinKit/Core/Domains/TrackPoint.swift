import Foundation

public struct TrackPoint: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double?
    public let timestamp: Date?

    public init(latitude: Double, longitude: Double, elevation: Double?, timestamp: Date?) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.timestamp = timestamp
    }

    public var hasValidCoordinate: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90 ... 90).contains(latitude)
            && (-180 ... 180).contains(longitude)
    }
}

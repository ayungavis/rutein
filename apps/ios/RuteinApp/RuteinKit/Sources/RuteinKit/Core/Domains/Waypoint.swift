public struct Waypoint: Sendable, Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double?

    public init(name: String, latitude: Double, longitude: Double, elevation: Double?) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }

    public var hasValidCoordinate: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90 ... 90).contains(latitude)
            && (-180 ... 180).contains(longitude)
    }
}

public enum CheckpointOrigin: String, Sendable, Equatable, Codable {
    case waypoint
    case distanceMarker
}

public enum CheckpointElevationSource: String, Sendable, Equatable, Codable {
    case waypoint
    case geometry
    case unavailable
}

public struct Checkpoint: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String?
    public let distanceMetres: Double
    public let elevationMetres: Double?
    public let origin: CheckpointOrigin
    public let elevationSource: CheckpointElevationSource

    public init(
        id: Int,
        name: String?,
        distanceMetres: Double,
        elevationMetres: Double?,
        origin: CheckpointOrigin,
        elevationSource: CheckpointElevationSource,
    ) {
        self.id = id
        self.name = name
        self.distanceMetres = distanceMetres
        self.elevationMetres = elevationMetres
        self.origin = origin
        self.elevationSource = elevationSource
    }
}

public struct CheckpointSet: Sendable, Equatable {
    public let checkpoints: [Checkpoint]
    public let unassociated: [String]
    public let ambiguous: [String]

    public init(checkpoints: [Checkpoint], unassociated: [String], ambiguous: [String]) {
        self.checkpoints = checkpoints
        self.unassociated = unassociated
        self.ambiguous = ambiguous
    }

    public var usesDistanceMarkers: Bool {
        !checkpoints.isEmpty && checkpoints.allSatisfy { $0.origin == .distanceMarker }
    }

    public var hasDataQualityNote: Bool {
        !unassociated.isEmpty || !ambiguous.isEmpty
    }
}

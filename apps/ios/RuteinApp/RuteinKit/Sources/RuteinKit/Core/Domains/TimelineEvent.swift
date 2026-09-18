public enum TimelineEventKind: String, Sendable, Equatable {
    case start
    case checkpoint
    case distanceMarker
    case drink
    case fuel
    case finish

    var rank: Int {
        switch self {
        case .start: 0
        case .checkpoint: 1
        case .distanceMarker: 2
        case .drink: 3
        case .fuel: 4
        case .finish: 5
        }
    }
}

public struct TimelineEvent: Identifiable, Sendable, Equatable {
    public let id: Int
    public let kind: TimelineEventKind
    public let name: String?
    public let elapsedSeconds: Double
    public let distanceMetres: Double?
    public let elevationMetres: Double?

    public init(
        id: Int,
        kind: TimelineEventKind,
        name: String?,
        elapsedSeconds: Double,
        distanceMetres: Double?,
        elevationMetres: Double?,
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.elapsedSeconds = elapsedSeconds
        self.distanceMetres = distanceMetres
        self.elevationMetres = elevationMetres
    }
}

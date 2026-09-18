import Foundation

public struct StoredRoute: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let summary: RouteSummary
    public let outline: [RouteOutlinePoint]
    public let fingerprint: String
    public let updatedAt: Date
    public let plan: RoutePlan?
    public let source: RouteSource?

    public init(
        id: UUID,
        name: String,
        summary: RouteSummary,
        outline: [RouteOutlinePoint],
        fingerprint: String,
        updatedAt: Date,
        plan: RoutePlan? = nil,
        source: RouteSource? = nil,
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.outline = outline
        self.fingerprint = fingerprint
        self.updatedAt = updatedAt
        self.plan = plan
        self.source = source
    }

    public static func == (lhs: StoredRoute, rhs: StoredRoute) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

import Foundation

public struct OpenedRoute: Identifiable, Sendable, Hashable {
    public let route: ImportedRoute
    public let data: Data?
    public let isSaved: Bool
    public let plan: RoutePlan?

    public init(route: ImportedRoute, data: Data?, isSaved: Bool, plan: RoutePlan? = nil) {
        self.route = route
        self.data = data
        self.isSaved = isSaved
        self.plan = plan
    }

    public var id: UUID {
        route.id
    }

    public static func == (lhs: OpenedRoute, rhs: OpenedRoute) -> Bool {
        lhs.id == rhs.id && lhs.isSaved == rhs.isSaved
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

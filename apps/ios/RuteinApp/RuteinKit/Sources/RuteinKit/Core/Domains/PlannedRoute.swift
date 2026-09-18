import Foundation

public struct PlannedRoute: Identifiable, Sendable, Hashable {
    public let opened: OpenedRoute
    public let plan: RoutePlan

    public init(opened: OpenedRoute, plan: RoutePlan) {
        self.opened = opened
        self.plan = plan
    }

    public var id: UUID {
        opened.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(opened)
    }
}

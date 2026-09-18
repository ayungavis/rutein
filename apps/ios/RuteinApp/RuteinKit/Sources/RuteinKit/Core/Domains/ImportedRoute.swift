import Foundation

public struct ImportedRoute: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let geometry: RouteGeometry
    public let summary: RouteSummary
    public let sourceKind: RouteSourceKind
    public let sourceIndex: Int
    public let sourceName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        geometry: RouteGeometry,
        summary: RouteSummary,
        sourceKind: RouteSourceKind = .track,
        sourceIndex: Int = 0,
        sourceName: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.geometry = geometry
        self.summary = summary
        self.sourceKind = sourceKind
        self.sourceIndex = sourceIndex
        self.sourceName = sourceName
    }

    public static func == (lhs: ImportedRoute, rhs: ImportedRoute) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

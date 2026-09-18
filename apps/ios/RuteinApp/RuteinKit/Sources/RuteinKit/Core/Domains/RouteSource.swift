public struct RouteSource: Sendable, Equatable, Codable {
    public let kind: RouteSourceKind
    public let index: Int
    public let name: String?

    public init(kind: RouteSourceKind, index: Int, name: String?) {
        self.kind = kind
        self.index = index
        self.name = name
    }
}

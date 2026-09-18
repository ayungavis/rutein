import Foundation

public struct ImportedFile: Sendable {
    public let route: ImportedRoute
    public let data: Data

    public init(route: ImportedRoute, data: Data) {
        self.route = route
        self.data = data
    }
}

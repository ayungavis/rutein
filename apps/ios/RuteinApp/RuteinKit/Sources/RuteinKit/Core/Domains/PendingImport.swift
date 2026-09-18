import Foundation

public struct PendingImport: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let data: Data
    public let document: GPXDocument

    public init(name: String, data: Data, document: GPXDocument) {
        self.name = name
        self.data = data
        self.document = document
    }

    public var choices: [RouteCandidate] {
        document.preferred
    }
}

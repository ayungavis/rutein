import Foundation

public struct DuplicateRoute: Identifiable, Sendable {
    public let existing: StoredRoute
    public let incoming: ImportedFile

    public init(existing: StoredRoute, incoming: ImportedFile) {
        self.existing = existing
        self.incoming = incoming
    }

    public var id: UUID {
        existing.id
    }
}

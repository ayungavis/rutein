import Foundation

public protocol RouteRepository: Sendable {
    func routes() async throws -> [StoredRoute]
    func route(id: UUID) async throws -> StoredRoute?
    func existing(fingerprint: String) async throws -> StoredRoute?
    func save(_ file: ImportedFile) async throws -> StoredRoute
    func savePlan(_ plan: RoutePlan, for id: UUID) async throws -> StoredRoute
    func rename(id: UUID, to name: String) async throws -> StoredRoute
    func delete(id: UUID) async throws
    func reconcile() async throws -> Int
    func geometry(id: UUID) async throws -> RouteGeometry
}

public struct UnavailableRouteRepository: RouteRepository {
    public init() {}

    public func routes() async throws -> [StoredRoute] {
        throw AppError.storage
    }

    public func route(id _: UUID) async throws -> StoredRoute? {
        throw AppError.storage
    }

    public func existing(fingerprint _: String) async throws -> StoredRoute? {
        throw AppError.storage
    }

    public func save(_: ImportedFile) async throws -> StoredRoute {
        throw AppError.storage
    }

    public func savePlan(_: RoutePlan, for _: UUID) async throws -> StoredRoute {
        throw AppError.storage
    }

    public func rename(id _: UUID, to _: String) async throws -> StoredRoute {
        throw AppError.storage
    }

    public func reconcile() async throws -> Int {
        throw AppError.storage
    }

    public func delete(id _: UUID) async throws {
        throw AppError.storage
    }

    public func geometry(id _: UUID) async throws -> RouteGeometry {
        throw AppError.storage
    }
}

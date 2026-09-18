import Foundation
@testable import RuteinKit

actor FakeRouteRepository: RouteRepository {
    private var stored: [StoredRoute] = []
    private var geometries: [UUID: RouteGeometry] = [:]
    private var failure: AppError?

    init(stored: [StoredRoute] = []) {
        self.stored = stored
    }

    func fail(with error: AppError?) {
        failure = error
    }

    func put(_ route: StoredRoute, geometry: RouteGeometry? = nil) {
        stored.removeAll { $0.id == route.id }
        stored.insert(route, at: 0)

        if let geometry {
            geometries[route.id] = geometry
        }
    }

    func routes() async throws -> [StoredRoute] {
        try check()
        return stored
    }

    func route(id: UUID) async throws -> StoredRoute? {
        try check()
        return stored.first { $0.id == id }
    }

    func existing(fingerprint: String) async throws -> StoredRoute? {
        try check()
        return stored.first { $0.fingerprint == fingerprint }
    }

    func save(_ file: ImportedFile) async throws -> StoredRoute {
        try check()

        let route = try StoredRoute(
            id: file.route.id,
            name: RouteName.validated(file.route.name),
            summary: file.route.summary,
            outline: RouteOutline.points(from: file.route.geometry),
            fingerprint: RouteFingerprint.of(file.data),
            updatedAt: .now,
        )

        put(route, geometry: file.route.geometry)

        return route
    }

    func savePlan(_ plan: RoutePlan, for id: UUID) async throws -> StoredRoute {
        try check()

        guard let existing = stored.first(where: { $0.id == id }) else {
            throw AppError.storage
        }

        let planned = StoredRoute(
            id: existing.id,
            name: existing.name,
            summary: existing.summary,
            outline: existing.outline,
            fingerprint: existing.fingerprint,
            updatedAt: .now,
            plan: plan,
        )

        put(planned)

        return planned
    }

    func rename(id: UUID, to name: String) async throws -> StoredRoute {
        try check()

        let validated = try RouteName.validated(name)

        guard let existing = stored.first(where: { $0.id == id }) else {
            throw AppError.storage
        }

        let renamed = StoredRoute(
            id: existing.id,
            name: validated,
            summary: existing.summary,
            outline: existing.outline,
            fingerprint: existing.fingerprint,
            updatedAt: .now,
            plan: existing.plan,
        )

        put(renamed)

        return renamed
    }

    func delete(id: UUID) async throws {
        try check()
        stored.removeAll { $0.id == id }
        geometries[id] = nil
    }

    func reconcile() async throws -> Int {
        try check()

        return 0
    }

    func geometry(id: UUID) async throws -> RouteGeometry {
        try check()

        guard let geometry = geometries[id] else {
            throw AppError.access
        }

        return geometry
    }

    private func check() throws {
        if let failure {
            throw failure
        }
    }
}

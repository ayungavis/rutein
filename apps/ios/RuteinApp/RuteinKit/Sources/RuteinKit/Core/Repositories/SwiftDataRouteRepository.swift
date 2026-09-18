import Foundation
import SwiftData

public actor SwiftDataRouteRepository: RouteRepository {
    private typealias Record = RouteSchemaV3.SavedRoute

    private let context: ModelContext
    private let files: RouteFileStore

    public init(container: ModelContainer, files: RouteFileStore) {
        context = ModelContext(container)
        self.files = files
    }

    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: RouteSchemaV3.SavedRoute.self,
                migrationPlan: RouteMigrationPlan.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory),
            )
        } catch {
            throw AppError.storage
        }
    }

    public func routes() async throws -> [StoredRoute] {
        try fetch(FetchDescriptor<Record>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
            .map(\.stored)
    }

    public func route(id: UUID) async throws -> StoredRoute? {
        try record(id: id)?.stored
    }

    public func existing(fingerprint: String) async throws -> StoredRoute? {
        var descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.fingerprint == fingerprint })
        descriptor.fetchLimit = 1

        return try fetch(descriptor).first?.stored
    }

    public func save(_ file: ImportedFile) async throws -> StoredRoute {
        let identifier = file.route.id
        let fileName = RouteFileStore.fileName(for: identifier)

        try files.write(file.data, named: fileName)

        let record = try Record(
            identifier: identifier,
            name: RouteName.validated(file.route.name),
            fingerprint: RouteFingerprint.of(file.route, in: file.data),
            fileName: fileName,
            updatedAt: .now,
            summary: file.route.summary,
            outline: RouteOutline.points(from: file.route.geometry),
            source: RouteSource(
                kind: file.route.sourceKind,
                index: file.route.sourceIndex,
                name: file.route.sourceName,
            ),
        )

        context.insert(record)

        do {
            try context.save()
        } catch {
            try? files.remove(fileName)
            throw AppError.storage
        }

        return record.stored
    }

    public func savePlan(_ plan: RoutePlan, for id: UUID) async throws -> StoredRoute {
        guard let record = try record(id: id) else {
            throw AppError.storage
        }

        record.plan = plan
        record.updatedAt = .now

        do {
            try context.save()
        } catch {
            throw AppError.storage
        }

        return record.stored
    }

    public func rename(id: UUID, to name: String) async throws -> StoredRoute {
        let validated = try RouteName.validated(name)

        guard let record = try record(id: id) else {
            throw AppError.storage
        }

        record.name = validated
        record.updatedAt = .now

        do {
            try context.save()
        } catch {
            throw AppError.storage
        }

        return record.stored
    }

    public func delete(id: UUID) async throws {
        guard let record = try record(id: id) else {
            return
        }

        let fileName = record.fileName

        context.delete(record)

        do {
            try context.save()
        } catch {
            throw AppError.storage
        }

        try files.remove(fileName)
    }

    public func reconcile() async throws -> Int {
        let known = try Set(fetch(FetchDescriptor<Record>()).map(\.fileName))
        let orphans = try files.fileNames().filter { !known.contains($0) }

        for orphan in orphans {
            try? files.remove(orphan)
        }

        return orphans.count
    }

    public func geometry(id: UUID) async throws -> RouteGeometry {
        guard let record = try record(id: id) else {
            throw AppError.access
        }

        let document = try await GPXParser.parse(files.read(record.fileName))
        let chosen = record.source.flatMap { source in
            document.usable.first { $0.kind == source.kind && $0.id == source.index }
        }

        guard let candidate = chosen ?? document.preferred.first else {
            throw AppError.geometry
        }

        return document.geometry(for: candidate)
    }

    private func record(id: UUID) throws -> Record? {
        var descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.identifier == id })
        descriptor.fetchLimit = 1

        return try fetch(descriptor).first
    }

    private func fetch(_ descriptor: FetchDescriptor<Record>) throws -> [Record] {
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.storage
        }
    }
}

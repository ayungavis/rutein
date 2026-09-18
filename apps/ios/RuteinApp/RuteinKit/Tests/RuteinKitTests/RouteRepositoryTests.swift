import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteRepository")
struct RouteRepositoryTests {
    private struct Harness {
        let repository: SwiftDataRouteRepository
        let root: URL

        var directory: URL {
            root.appending(path: RouteFileStore.directoryName)
        }
    }

    private func harness() throws -> Harness {
        let root = URL.temporaryDirectory.appending(path: "rutein-tests-\(UUID().uuidString)")

        return try Harness(
            repository: SwiftDataRouteRepository(
                container: SwiftDataRouteRepository.container(inMemory: true),
                files: RouteFileStore(root: root),
            ),
            root: root,
        )
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    private func imported(_ name: String, called routeName: String = "Ridge Loop") async throws -> ImportedFile {
        let data = try fixture(name)
        let geometry = try await GPXParser.geometry(data)

        return try await ImportedFile(
            route: ImportedRoute(
                name: routeName,
                geometry: geometry,
                summary: RouteAnalyzer.analyse(geometry),
            ),
            data: data,
        )
    }

    @Test("A saved route comes back with its metrics and outline")
    func savedRouteComesBack() async throws {
        let harness = try harness()
        let file = try await imported("wikiloc-mt-agung")

        let saved = try await harness.repository.save(file)
        let routes = try await harness.repository.routes()

        #expect(routes.count == 1)
        #expect(routes.first?.id == saved.id)
        #expect(routes.first?.name == "Ridge Loop")
        #expect(abs((routes.first?.summary.distanceMetres ?? 0) - 12437.447) < 0.01)
        #expect(routes.first?.outline.count == RouteOutline.pointBudget)
    }

    @Test("The library is sorted most recently updated first")
    func libraryIsSortedByRecency() async throws {
        let harness = try harness()

        _ = try await harness.repository.save(imported("wikiloc-mt-agung", called: "First"))
        _ = try await harness.repository.save(imported("wikiloc-mt-agung", called: "Second"))

        let names = try await harness.repository.routes().map(\.name)

        #expect(names == ["Second", "First"])
    }

    @Test("An identical file is found by its fingerprint")
    func identicalFileIsFoundByFingerprint() async throws {
        let harness = try harness()
        let file = try await imported("wikiloc-mt-agung")

        _ = try await harness.repository.save(file)

        let match = try await harness.repository.existing(fingerprint: RouteFingerprint.of(file.data))
        let miss = try await harness.repository.existing(fingerprint: RouteFingerprint.of(Data([0x01])))

        #expect(match?.name == "Ridge Loop")
        #expect(miss == nil)
    }

    @Test("The owned filename comes from the identifier, never the route name")
    func ownedFilenameComesFromTheIdentifier() async throws {
        let harness = try harness()
        let file = try await imported("wikiloc-mt-agung", called: "../../etc/passwd")

        let saved = try await harness.repository.save(file)
        let contents = try FileManager.default.contentsOfDirectory(atPath: harness.directory.path)

        #expect(contents == ["\(saved.id.uuidString).gpx"])
    }

    @Test("Renaming trims the name and moves the route to the top")
    func renamingTrimsAndTouches() async throws {
        let harness = try harness()
        let saved = try await harness.repository.save(imported("wikiloc-mt-agung", called: "First"))

        _ = try await harness.repository.save(imported("wikiloc-mt-agung", called: "Second"))

        let renamed = try await harness.repository.rename(id: saved.id, to: "  Agung Summit  ")

        #expect(renamed.name == "Agung Summit")
        #expect(renamed.updatedAt > saved.updatedAt)
        #expect(try await harness.repository.routes().map(\.name) == ["Agung Summit", "Second"])
    }

    @Test("A blank or over-long name is refused")
    func blankOrOverLongNameIsRefused() async throws {
        let harness = try harness()
        let saved = try await harness.repository.save(imported("wikiloc-mt-agung"))

        await #expect(throws: AppError.dataQuality) {
            _ = try await harness.repository.rename(id: saved.id, to: "   ")
        }

        await #expect(throws: AppError.dataQuality) {
            _ = try await harness.repository.rename(id: saved.id, to: String(repeating: "a", count: 81))
        }

        #expect(try await harness.repository.route(id: saved.id)?.name == "Ridge Loop")
    }

    @Test("Deleting removes the record and its owned file, leaving others intact")
    func deletingRemovesRecordAndFile() async throws {
        let harness = try harness()
        let first = try await harness.repository.save(imported("wikiloc-mt-agung", called: "First"))
        let second = try await harness.repository.save(imported("wikiloc-mt-agung", called: "Second"))

        try await harness.repository.delete(id: first.id)

        let contents = try FileManager.default.contentsOfDirectory(atPath: harness.directory.path)

        #expect(try await harness.repository.routes().map(\.name) == ["Second"])
        #expect(contents == ["\(second.id.uuidString).gpx"])
    }

    @Test("A file with no record behind it is swept, and real routes are left alone")
    func orphanFilesAreSwept() async throws {
        let harness = try harness()
        let saved = try await harness.repository.save(imported("wikiloc-mt-agung"))
        let orphan = harness.directory.appending(path: "\(UUID().uuidString).gpx")

        try Data("<gpx/>".utf8).write(to: orphan)

        let swept = try await harness.repository.reconcile()
        let remaining = try FileManager.default.contentsOfDirectory(atPath: harness.directory.path)

        #expect(swept == 1)
        #expect(remaining == ["\(saved.id.uuidString).gpx"])
        #expect(try await harness.repository.routes().count == 1)
    }

    @Test("A tidy store sweeps nothing")
    func tidyStoreSweepsNothing() async throws {
        let harness = try harness()

        _ = try await harness.repository.save(imported("wikiloc-mt-agung"))

        #expect(try await harness.repository.reconcile() == 0)
    }

    @Test("The chosen track is reparsed on reopen, not the first one")
    func reopenReparsesTheChosenTrack() async throws {
        let harness = try harness()
        let data = try fixture("two-tracks")
        let document = try await GPXParser.parse(data)
        let second = try #require(document.candidates.last)
        let geometry = document.geometry(for: second)
        let file = try await ImportedFile(
            route: ImportedRoute(
                name: "Descent",
                geometry: geometry,
                summary: RouteAnalyzer.analyse(geometry),
                sourceKind: second.kind,
                sourceIndex: second.id,
                sourceName: second.name,
            ),
            data: data,
        )

        let saved = try await harness.repository.save(file)

        #expect(saved.source?.index == 1)
        #expect(try await harness.repository.geometry(id: saved.id).pointCount == 4)
    }

    @Test("Reopening a route reparses the geometry from the owned file")
    func reopeningReparsesGeometry() async throws {
        let harness = try harness()
        let saved = try await harness.repository.save(imported("wikiloc-mt-agung"))

        let geometry = try await harness.repository.geometry(id: saved.id)

        #expect(geometry.pointCount == 256)
    }

    @Test("A missing owned file fails as access, so the UI can offer reimport")
    func missingOwnedFileFailsAsAccess() async throws {
        let harness = try harness()
        let saved = try await harness.repository.save(imported("wikiloc-mt-agung"))

        try FileManager.default.removeItem(at: harness.directory.appending(path: "\(saved.id.uuidString).gpx"))

        await #expect(throws: AppError.access) {
            _ = try await harness.repository.geometry(id: saved.id)
        }
    }

    @Test("Storage that could not open reports itself rather than looking empty")
    func unavailableStorageReportsItself() async throws {
        let repository = UnavailableRouteRepository()

        await #expect(throws: AppError.storage) {
            _ = try await repository.routes()
        }

        await #expect(throws: AppError.storage) {
            _ = try await repository.geometry(id: UUID())
        }
    }
}

import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteImportService")
struct RouteImportServiceTests {
    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
    }

    private func imported(_ name: String) async throws -> ImportedRoute {
        let data = try RouteImportService.read(from: fixture(name))
        let document = try await RouteImportService.document(data)
        let candidate = try #require(document.preferred.first)

        return try await RouteImportService.route(
            named: RouteImportService.suggestedName(for: fixture(name)),
            from: document,
            candidate: candidate,
        )
    }

    @Test("A real export becomes a route named after its file, tagged with its source")
    func realExportBecomesANamedRoute() async throws {
        let route = try await imported("wikiloc-mt-agung")

        #expect(route.name == "wikiloc-mt-agung")
        #expect(abs(route.summary.distanceMetres - 12437.447) < 0.01)
        #expect(route.geometry.pointCount == 256)
        #expect(route.sourceKind == .track)
        #expect(route.sourceIndex == 0)
    }

    @Test("The fingerprint distinguishes two tracks in the same file")
    func fingerprintDistinguishesTracks() async throws {
        let data = try RouteImportService.read(from: fixture("two-tracks"))
        let document = try await RouteImportService.document(data)

        let first = RouteFingerprint.of(data, kind: .track, index: document.candidates[0].id)
        let second = RouteFingerprint.of(data, kind: .track, index: document.candidates[1].id)

        #expect(first != second)
        #expect(first == RouteFingerprint.of(data, kind: .track, index: 0))
    }

    @Test("Malformed XML fails as a format error")
    func malformedFailsAsFormat() async throws {
        await #expect(throws: AppError.format) {
            _ = try await RouteImportService.document(
                RouteImportService.read(from: fixture("mailformed")),
            )
        }
    }

    @Test("A waypoint-only file fails as a geometry error")
    func waypointOnlyFailsAsGeometry() async throws {
        await #expect(throws: AppError.geometry) {
            _ = try await RouteImportService.document(
                RouteImportService.read(from: fixture("waypoints-only")),
            )
        }
    }

    @Test("A missing file fails as an access error rather than crashing")
    func missingFileFailsAsAccess() throws {
        let missing = URL(fileURLWithPath: "/tmp/rutein-does-not-exist.gpx")

        #expect(throws: AppError.access) {
            _ = try RouteImportService.read(missing)
        }
    }

    @Test("A file over the size limit fails as a capacity error")
    func oversizedFileFailsAsCapacity() throws {
        let url = URL.temporaryDirectory.appending(path: "rutein-oversized.gpx")
        let oversized = Data(count: RouteImportService.maximumFileBytes + 1)

        try oversized.write(to: url)

        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: AppError.capacity) {
            _ = try RouteImportService.read(url)
        }
    }
}

import Foundation
import Testing
@testable import RuteinKit

@Suite("GPX 1.0")
struct GPXLegacyTests {
    private func document(_ name: String) async throws -> GPXDocument {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))

        return try await GPXParser.parse(Data(contentsOf: url))
    }

    @Test("A GPX 1.0 track passes the same pipeline as a 1.1 one")
    func legacyTrackPassesThePipeline() async throws {
        let document = try await document("gpx10-track")
        let candidate = try #require(document.usable.first)
        let geometry = document.geometry(for: candidate)
        let summary = try await RouteAnalyzer.analyse(geometry)

        #expect(document.usable.count == 1)
        #expect(candidate.kind == .track)
        #expect(candidate.name == "Ten Zero Ladder")
        #expect(geometry.pointCount == 4)
        #expect(abs(summary.distanceMetres - 1667.9262035029935) < 0.000001)
        #expect(summary.ascentMetres == 100)
        #expect(summary.elevationCoverage == .complete)
    }

    @Test("A GPX 1.0 waypoint is read, and 1.0-only elements are ignored safely")
    func legacyWaypointIsReadAndExtrasIgnored() async throws {
        let document = try await document("gpx10-track")
        let waypoint = try #require(document.waypoints.first)

        #expect(document.waypoints.count == 1)
        #expect(waypoint.name == "Spring")
        #expect(waypoint.elevation == 140)
    }

    @Test("The file-level name never becomes a track name")
    func fileLevelNameNeverBecomesATrackName() async throws {
        let names = try await document("gpx10-track").candidates.map(\.name)

        #expect(names == ["Ten Zero Ladder"])
    }

    @Test("A prefixed namespace parses by local name")
    func prefixedNamespaceParses() async throws {
        let document = try await document("gpx10-prefixed")
        let candidate = try #require(document.usable.first)
        let summary = try await RouteAnalyzer.analyse(document.geometry(for: candidate))

        #expect(candidate.kind == .route)
        #expect(candidate.name == "Prefixed Route")
        #expect(document.geometry(for: candidate).pointCount == 3)
        #expect(abs(summary.distanceMetres - 1111.9508023353292) < 0.000001)
        #expect(summary.ascentMetres == 110)
    }

    @Test("A 1.0 route reaches a timeline exactly as a 1.1 one does")
    func legacyRouteReachesATimeline() async throws {
        let document = try await document("gpx10-prefixed")
        let candidate = try #require(document.usable.first)
        let geometry = document.geometry(for: candidate)
        let summary = try await RouteAnalyzer.analyse(geometry)
        let plan = try RoutePlan(targetDurationSeconds: 3600)
        let events = RouteTimeline.events(
            for: plan,
            checkpoints: CheckpointAssociation.checkpoints(
                in: geometry,
                totalDistanceMetres: summary.distanceMetres,
            ).checkpoints,
            totalDistanceMetres: summary.distanceMetres,
        )

        #expect(events.map(\.kind) == [.start, .finish])
        #expect(events.last?.elapsedSeconds == 3600)
    }
}

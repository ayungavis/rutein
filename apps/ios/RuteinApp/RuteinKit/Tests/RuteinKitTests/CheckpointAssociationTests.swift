import Foundation
import Testing
@testable import RuteinKit

@Suite("CheckpointAssociation")
struct CheckpointAssociationTests {
    private func geometry(_ name: String) async throws -> RouteGeometry {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))

        return try await GPXParser.geometry(Data(contentsOf: url))
    }

    private func set(_ name: String) async throws -> CheckpointSet {
        let geometry = try await geometry(name)
        let summary = try await RouteAnalyzer.analyse(geometry)

        return CheckpointAssociation.checkpoints(
            in: geometry,
            totalDistanceMetres: summary.distanceMetres,
        )
    }

    private func line(_ latitudes: [Double], elevation: Double? = 100) -> [TrackPoint] {
        latitudes.map {
            TrackPoint(latitude: $0, longitude: 0, elevation: elevation, timestamp: nil)
        }
    }

    @Test("A waypoint on the line lands at its own route distance")
    func waypointOnTheLineLandsAtItsDistance() async throws {
        let checkpoints = try await set("with-waypoints").checkpoints

        #expect(checkpoints.count == 2)
        #expect(abs(checkpoints[0].distanceMetres - 5000) < 0.01)
        #expect(abs(checkpoints[1].distanceMetres - 10000) < 0.01)
    }

    @Test("Checkpoints are ordered by route distance, never by XML order")
    func checkpointsAreOrderedByRouteDistance() async throws {
        let checkpoints = try await set("with-waypoints").checkpoints

        #expect(checkpoints.map(\.name) == ["Water point", "Ridge junction"])
        #expect(checkpoints.map(\.id) == [0, 1])
    }

    @Test("A waypoint's own elevation wins; without one the geometry supplies it")
    func elevationSourceIsRecorded() async throws {
        let checkpoints = try await set("with-waypoints").checkpoints

        #expect(checkpoints[0].elevationSource == .geometry)
        #expect(abs((checkpoints[0].elevationMetres ?? 0) - 279.864) < 0.001)
        #expect(checkpoints[1].elevationSource == .waypoint)
        #expect(checkpoints[1].elevationMetres == 512.5)
    }

    @Test("A waypoint further than the matching distance gets no estimate at all")
    func distantWaypointIsUnassociated() async throws {
        let associated = try await set("with-waypoints")

        #expect(associated.unassociated == ["Trailhead parking"])
        #expect(associated.checkpoints.allSatisfy { $0.name != "Trailhead parking" })
        #expect(associated.hasDataQualityNote)
    }

    @Test("A waypoint beside an out-and-back is ambiguous and omitted from timing")
    func outAndBackWaypointIsAmbiguous() {
        let outward = (0 ..< 10).map { Double($0) * 0.001 }
        let geometry = RouteGeometry(
            segments: [line(outward + outward.reversed())],
            waypoints: [
                Waypoint(name: "Saddle", latitude: 0.005, longitude: 0.0002, elevation: nil),
            ],
        )

        let associated = CheckpointAssociation.checkpoints(in: geometry, totalDistanceMetres: 2000)

        #expect(associated.ambiguous == ["Saddle"])
        #expect(associated.checkpoints.allSatisfy { $0.origin == .distanceMarker })
    }

    @Test("A route with no usable waypoints falls back to markers every 5 km")
    func noWaypointsFallsBackToMarkers() async throws {
        let associated = try await set("wikiloc-mt-agung")
        let geometry = try await RouteGeometry(segments: geometry("wikiloc-mt-agung").segments)
        let markers = CheckpointAssociation.checkpoints(in: geometry, totalDistanceMetres: 12437.447)

        #expect(!associated.checkpoints.isEmpty)
        #expect(markers.usesDistanceMarkers)
        #expect(markers.checkpoints.map(\.distanceMetres) == [5000, 10000])
        #expect(markers.checkpoints.allSatisfy { $0.name == nil })
    }

    @Test("A marker never lands on the finish")
    func markerNeverLandsOnTheFinish() {
        let geometry = RouteGeometry(segments: [line((0 ..< 180).map { Double($0) * 0.001 })])
        let markers = CheckpointAssociation.markers(in: geometry, totalDistanceMetres: 10000)

        #expect(markers.map(\.distanceMetres) == [5000])
    }

    @Test("A route shorter than one marker interval carries only Start and Finish")
    func shortRouteHasNoMarkers() {
        let geometry = RouteGeometry(segments: [line((0 ..< 20).map { Double($0) * 0.001 })])

        #expect(CheckpointAssociation.markers(in: geometry, totalDistanceMetres: 2100).isEmpty)
    }

    @Test("A marker carries the elevation the geometry has at that distance")
    func markerCarriesInterpolatedElevation() {
        let points = (0 ..< 180).map { index in
            TrackPoint(
                latitude: Double(index) * 0.001,
                longitude: 0,
                elevation: 100 + Double(index) * 4,
                timestamp: nil,
            )
        }
        let markers = CheckpointAssociation.markers(
            in: RouteGeometry(segments: [points]),
            totalDistanceMetres: 19903.9,
        )

        #expect(markers.count == 3)
        #expect(markers[0].elevationSource == .geometry)
        #expect(abs((markers[0].elevationMetres ?? 0) - 279.864) < 0.001)
    }

    @Test("A marker over geometry with no elevation says so rather than guessing")
    func markerWithoutElevationSaysSo() {
        let geometry = RouteGeometry(segments: [line((0 ..< 180).map { Double($0) * 0.001 }, elevation: nil)])
        let markers = CheckpointAssociation.markers(in: geometry, totalDistanceMetres: 19903.9)

        #expect(markers.allSatisfy { $0.elevationMetres == nil })
        #expect(markers.allSatisfy { $0.elevationSource == .unavailable })
    }

    @Test("The real out-and-back marks six of its seven waypoints ambiguous")
    func realOutAndBackIsMostlyAmbiguous() async throws {
        let associated = try await set("wikiloc-mt-agung")

        #expect(associated.ambiguous.count == 6)
        #expect(associated.ambiguous.allSatisfy { $0 == "Mountain pass" })
        #expect(associated.checkpoints.map(\.name) == ["Religious site"])
    }
}

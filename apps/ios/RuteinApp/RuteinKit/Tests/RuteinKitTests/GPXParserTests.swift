import Foundation
import RuteinKit
import Testing

@Suite("GPXParser")
struct GPXParserTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    private func oversizedGeometry() throws -> Data {
        var xml = "<gpx version=\"1.1\"><trk><trkseg>"

        for index in 0 ... GPXLimits.maximumGeometryPoints {
            xml += "<trkpt lat=\"\(Double(index) * 0.00001)\" lon=\"0\"/>"
        }

        return Data((xml + "</trkseg></trk></gpx>").utf8)
    }

    private func oversizedWaypoints() throws -> Data {
        var xml = "<gpx version=\"1.1\">"

        for index in 0 ... GPXLimits.maximumWaypoints {
            xml += "<wpt lat=\"0\" lon=\"0\"><name>W\(index)</name></wpt>"
        }

        return Data((xml + "<trk><trkseg><trkpt lat=\"0\" lon=\"0\"/>"
                + "<trkpt lat=\"0.001\" lon=\"0\"/></trkseg></trk></gpx>").utf8)
    }

    @Test("A single-track file yields one segment of three points")
    func parsesSingleTrack() async throws {
        let geometry = try await GPXParser.geometry(fixture("minimal"))

        #expect(geometry.segments.count == 1)
        #expect(geometry.pointCount == 3)
    }

    @Test("Elevation is read when present")
    func readsElevation() async throws {
        let geometry = try await GPXParser.geometry(fixture("minimal"))
        let first = try #require(geometry.segments.first?.first)

        #expect(first.elevation == 800.0)
        #expect(first.latitude == -6.9)
    }

    @Test("Mailformed XML is a format failure")
    func mailformedXMLFails() async throws {
        let data = try fixture("mailformed")

        await #expect(throws: AppError.format) {
            try await GPXParser.geometry(data)
        }
    }

    @Test("Two tracks stay two candidates and are never concatenated")
    func twoTracksStayTwoCandidates() async throws {
        let document = try await GPXParser.parse(fixture("two-tracks"))

        #expect(document.candidates.count == 2)
        #expect(document.usable.count == 2)
        #expect(document.candidates.map(\.name) == ["Ascent", "Descent"])
        #expect(document.candidates.map(\.kind) == [.track, .track])
        #expect(document.geometry(for: document.candidates[0]).pointCount == 3)
        #expect(document.geometry(for: document.candidates[1]).pointCount == 4)
    }

    @Test("A route is parsed and, when a track exists too, the track is preferred")
    func trackIsPreferredOverRoute() async throws {
        let mixed = try await GPXParser.parse(fixture("track-and-route"))
        let routeOnly = try await GPXParser.parse(fixture("route-only"))

        #expect(mixed.candidates.map(\.kind) == [.route, .track])
        #expect(mixed.preferred.map(\.kind) == [.track])
        #expect(routeOnly.preferred.map(\.kind) == [.route])
        #expect(try routeOnly.geometry(for: #require(routeOnly.preferred.first)).pointCount == 3)
    }

    @Test("A file past the point limit stops with a capacity failure")
    func pointLimitStopsProcessing() async throws {
        let data = try oversizedGeometry()

        await #expect(throws: AppError.capacity) {
            try await GPXParser.parse(data)
        }
    }

    @Test("A file past the waypoint limit stops with a capacity failure")
    func waypointLimitStopsProcessing() async throws {
        let data = try oversizedWaypoints()

        await #expect(throws: AppError.capacity) {
            try await GPXParser.parse(data)
        }
    }

    @Test("A cancelled parse throws cancelled rather than a half-read document")
    func cancelledParseThrowsCancelled() async throws {
        let data = try fixture("wikiloc-mt-agung")
        let task = Task {
            try await GPXParser.parse(data)
        }

        task.cancel()

        await #expect(throws: Error.self) {
            try await task.value
        }
    }

    @Test("A waypoint-only file has no usable geometry")
    func waypointOnlyFileFails() async throws {
        let data = try fixture("waypoints-only")

        await #expect(throws: AppError.geometry) {
            try await GPXParser.geometry(data)
        }
    }

    @Test("A real Wikiloc export parses into one segment")
    func parsesRealWikilocExport() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))

        #expect(geometry.segments.count == 1)
        #expect(geometry.pointCount == 256)
    }

    @Test("Standalone waypoints never become track points")
    func waypointsAreNotTrackPoints() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))

        #expect(geometry.pointCount == 256)
    }

    @Test("Southern and eastern coordinates keep their signs")
    func southernHemisphereSignsSurvive() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))
        let first = try #require(geometry.segments.first?.first)

        #expect(first.latitude == -8.363425)
        #expect(first.longitude == 115.461240)
        #expect(first.elevation == 1205.135)
    }

    @Test("Elevation spans the real climb")
    func elevationSpansTheClimb() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))
        let elevations = geometry.segments.flatMap(\.self).compactMap(\.elevation)

        #expect(elevations.count == 256)
        #expect(elevations.min() == 1205.135)
        #expect(elevations.max() == 3070.767)
    }
}

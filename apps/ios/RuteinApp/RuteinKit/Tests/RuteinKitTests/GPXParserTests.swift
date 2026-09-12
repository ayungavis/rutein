import Foundation
import RuteinKit
import Testing

@Suite("GPXParser")
struct GPXParserTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    @Test("A single-track file yields one segment of three points")
    func parsesSingleTrack() async throws {
        let geometry = try await GPXParser.parse(fixture("minimal"))

        #expect(geometry.segments.count == 1)
        #expect(geometry.pointCount == 3)
    }

    @Test("Elevation is read when present")
    func readsElevation() async throws {
        let geometry = try await GPXParser.parse(fixture("minimal"))
        let first = try #require(geometry.segments.first?.first)

        #expect(first.elevation == 800.0)
        #expect(first.latitude == -6.9)
    }

    @Test("Mailformed XML is a format failure")
    func mailformedXMLFails() async throws {
        let data = try fixture("mailformed")

        await #expect(throws: AppError.format) {
            try await GPXParser.parse(data)
        }
    }

    @Test("A waypoint-only file has no usable geometry")
    func waypointOnlyFileFails() async throws {
        let data = try fixture("waypoints-only")

        await #expect(throws: AppError.geometry) {
            try await GPXParser.parse(data)
        }
    }

    @Test("A real Wikiloc export parses into one segment")
    func parsesRealWikilocExport() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))

        #expect(geometry.segments.count == 1)
        #expect(geometry.pointCount == 256)
    }

    @Test("Standalone waypoints never become track points")
    func waypointsAreNotTrackPoints() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))

        #expect(geometry.pointCount == 256)
    }

    @Test("Southern and eastern coordinates keep their signs")
    func southernHemisphereSignsSurvive() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))
        let first = try #require(geometry.segments.first?.first)

        #expect(first.latitude == -8.363425)
        #expect(first.longitude == 115.461240)
        #expect(first.elevation == 1205.135)
    }

    @Test("Elevation spans the real climb")
    func elevationSpansTheClimb() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))
        let elevations = geometry.segments.flatMap(\.self).compactMap(\.elevation)

        #expect(elevations.count == 256)
        #expect(elevations.min() == 1205.135)
        #expect(elevations.max() == 3070.767)
    }
}

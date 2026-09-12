import Foundation
import RuteinKit
import Testing

@Suite("RouteAnalyzer")
struct RouteAnalyzerTests {
    private static let tolerance = 0.01

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    private func point(_ latitude: Double, _ longitude: Double) -> TrackPoint {
        TrackPoint(latitude: latitude, longitude: longitude, elevation: nil, timestamp: nil)
    }

    @Test("One degree of latitude is 111195.080 metres")
    func oneDegreeOfLatitude() {
        let metres = Haversine.metres(from: point(0, 0), to: point(1, 0))

        #expect(abs(metres - 111_195.080) < Self.tolerance)
    }

    @Test("A point is zero metres from itself")
    func identicalPointsAreZeroApart() {
        let metres = Haversine.metres(from: point(-8.363425, 115.461240), to: point(-8.363425, 115.461240))

        #expect(metres == 0)
    }

    @Test("Crossing the antimeridian takes the short way")
    func antimeridianTakesTheShortArc() {
        let metres = Haversine.metres(from: point(0, 179.999), to: point(0, -179.999))

        #expect(abs(metres - 222.390) < Self.tolerance)
    }

    @Test("A gap between segments contributes no distance")
    func segmentGapContributesNothing() async throws {
        let geometry = try await GPXParser.parse(fixture("two-segments"))
        let summary = try await RouteAnalyzer.analyse(geometry)

        #expect(abs(summary.distanceMetres - 2 * 111_195.080) < 1.0)
    }

    @Test("The real climb measures 12437.447 metres")
    func realRouteDistance() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))
        let summary = try await RouteAnalyzer.analyse(geometry)

        #expect(abs(summary.distanceMetres - 12437.447) < Self.tolerance)
    }

    @Test("Repeating the analysis gives the same number")
    func analysisIsDeterministic() async throws {
        let geometry = try await GPXParser.parse(fixture("wikiloc-mt-agung"))
        let first = try await RouteAnalyzer.analyse(geometry)
        let second = try await RouteAnalyzer.analyse(geometry)

        #expect(first == second)
    }
}

import Foundation
import RuteinKit
import Testing

@Suite("ElevationAnalysis")
struct ElevationAnalysisTests {
    private static let tolerance = 0.001

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    private func summary(_ name: String) async throws -> RouteSummary {
        try await RouteAnalyzer.analyse(GPXParser.parse(fixture(name)))
    }

    private func geometry(elevations: [Double]) -> RouteGeometry {
        let points = elevations.enumerated().map { index, elevation in
            TrackPoint(
                latitude: Double(index) * 0.001,
                longitude: 0,
                elevation: elevation,
                timestamp: nil,
            )
        }

        return RouteGeometry(segments: [points])
    }

    @Test("The real climb gains 1872.429 m and loses 1779.873 m")
    func realClimbAscentAndDescent() async throws {
        let result = try await summary("wikiloc-mt-agung")

        #expect(result.elevationCoverage == .complete)
        #expect(try abs(#require(result.ascentMetres) - 1872.429) < Self.tolerance)
        #expect(try abs(#require(result.descentMetres) - 1779.873) < Self.tolerance)
    }

    @Test("Ascent minus descent equals the net elevation change")
    func ascentMinusDescentIsTheNetChange() async throws {
        let result = try await summary("wikiloc-mt-agung")
        let net = try #require(result.ascentMetres) - #require(result.descentMetres)

        #expect(abs(net - 92.556) < Self.tolerance)
    }

    @Test("Raw extremes survive the median filter")
    func rawExtremesSurvive() async throws {
        let result = try await summary("wikiloc-mt-agung")

        #expect(result.minimumElevationMetres == 1205.135)
        #expect(result.maximumElevationMetres == 3070.767)
    }

    @Test("A flat route gains and loses nothing")
    func flatRouteIsFlat() async throws {
        let result = try await summary("flat")

        #expect(result.ascentMetres == 0)
        #expect(result.descentMetres == 0)
        #expect(result.elevationCoverage == .complete)
    }

    @Test("No elevation means unavailable, not zero")
    func missingElevationIsUnavailable() async throws {
        let result = try await summary("no-elevation")

        #expect(result.elevationCoverage == .unavailable)
        #expect(result.ascentMetres == nil)
        #expect(result.descentMetres == nil)
        #expect(result.minimumElevationMetres == nil)
    }

    @Test("A gap splits the run instead of being bridged")
    func gapIsNotBridged() async throws {
        let result = try await summary("partial-elevation")

        #expect(result.elevationCoverage == .partial)
        #expect(try abs(#require(result.ascentMetres) - 100.0) < Self.tolerance)
        #expect(result.minimumElevationMetres == 100.0)
        #expect(result.maximumElevationMetres == 950.0)
    }

    @Test("The median filter removes a single-sample spike")
    func medianFilterRemovesASpike() async throws {
        let spiked = geometry(elevations: [100.0, 100.5, 140.0, 101.0, 101.5])
        let result = try await RouteAnalyzer.analyse(spiked)

        #expect(result.ascentMetres == 0)
        #expect(result.descentMetres == 0)
        #expect(result.maximumElevationMetres == 140.0)
    }
}

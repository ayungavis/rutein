import Foundation
import Testing
@testable import RuteinKit

@Suite("ElevationProfile")
struct ElevationProfileTests {
    private func point(_ index: Int, elevation: Double?) -> TrackPoint {
        TrackPoint(
            latitude: Double(index) * 0.001,
            longitude: 0,
            elevation: elevation,
            timestamp: nil,
        )
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    @Test("Distance accumulates across the route")
    func distanceAccumulates() {
        let geometry = RouteGeometry(segments: [(0 ..< 4).map { point($0, elevation: 100) }])
        let profile = ElevationProfile.points(from: geometry)

        #expect(profile.count == 4)
        #expect(profile[0].distanceKilometres == 0)
        #expect(profile.map(\.distanceKilometres) == profile.map(\.distanceKilometres).sorted())
        #expect(abs(profile[3].distanceKilometres - 3 * 0.111195) < 0.001)
    }

    @Test("Points without elevation are left out rather than plotted as zero")
    func pointsWithoutElevationAreSkipped() {
        let segment = [
            point(0, elevation: 100),
            point(1, elevation: nil),
            point(2, elevation: 140),
        ]
        let profile = ElevationProfile.points(from: RouteGeometry(segments: [segment]))

        #expect(profile.count == 2)
        #expect(profile.map(\.elevationMetres) == [100, 140])
    }

    @Test("A route with no elevation yields no profile")
    func noElevationYieldsNoProfile() {
        let geometry = RouteGeometry(segments: [(0 ..< 4).map { point($0, elevation: nil) }])

        #expect(ElevationProfile.points(from: geometry).isEmpty)
    }

    @Test("A single elevation sample is not a profile")
    func singleSampleIsNotAProfile() {
        let segment = [point(0, elevation: 100), point(1, elevation: nil)]

        #expect(ElevationProfile.points(from: RouteGeometry(segments: [segment])).isEmpty)
    }

    @Test("A route larger than the sample budget is thinned to it")
    func largeRouteIsThinned() {
        let segment = (0 ..< 5000).map { point($0, elevation: 100 + Double($0 % 300)) }
        let profile = ElevationProfile.points(from: RouteGeometry(segments: [segment]))

        #expect(profile.count == ElevationProfile.sampleBudget)
        #expect(profile[0].distanceKilometres == 0)
        #expect(profile.map(\.distanceKilometres) == profile.map(\.distanceKilometres).sorted())
    }

    @Test("The real climb profiles end to end")
    func realClimbProfiles() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))
        let profile = ElevationProfile.points(from: geometry)

        #expect(profile.count == 256)
        #expect(abs((profile.last?.distanceKilometres ?? 0) - 12.437) < 0.01)

        let elevations = profile.map(\.elevationMetres)

        #expect(abs((elevations.min() ?? 0) - 1205.135) < 0.001)
        #expect(abs((elevations.max() ?? 0) - 3070.767) < 0.001)
    }
}
